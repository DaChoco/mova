using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Mova.Api.Data;
using Mova.Api.Dtos;

namespace Mova.Api.Controllers;

// Controller for handling user-related endpoints, such as retrieving user information and managing profile pictures. EVERY endpoint requires authentication via JWT.

[ApiController]
[Route("api/user")]
[Authorize] // All endpoints in this controller require the user to be authenticated via JWT.
public class UserController : ControllerBase
{
    private readonly AppDbContext _db;

    public UserController(AppDbContext db)
    {
        _db = db;
    }
    //retrieves user information based on the provided user ID.
   [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id)
    {
    var user = await _db.Users.FindAsync(id);
    if (user is null)
        return NotFound(new { success = false });

    return Ok(new
    {
        success = true,
        user = new
        {
            userId = user.UserId,
            studentNumber = user.StudentNumber,
            firstName = user.FirstName,
            surname = user.Surname,
            carID = user.CarId,
            profileIcon = user.ProfileIcon != null
                ? $"{Request.Scheme}://{Request.Host}/profilepicture/{user.ProfileIcon}"
                : null
        }
    });
    }

    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest req)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")!);

        var user = await _db.Users.FindAsync(userId);
        if (user is null)
            return NotFound(new { success = false });

        if (!BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash))
            return Unauthorized(new { success = false, message = "Current password is incorrect." });

        if (string.IsNullOrWhiteSpace(req.NewPassword) || req.NewPassword.Length < 6)
            return BadRequest(new { success = false, message = "New password must be at least 6 characters." });

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        await _db.SaveChangesAsync();

        var activeTokens = await _db.RefreshTokens
            .Where(rt => rt.UserId == userId && rt.RevokedAt == null)
            .ToListAsync();

        foreach (var t in activeTokens)
            t.RevokedAt = DateTime.UtcNow;

        return Ok(new { success = true, message = "Password changed successfully." });
    }

    // Uploads a new profile picture for the logged-in user. Validates file type and size, deletes any existing profile picture, and saves the new one.
    [HttpPost("profile-picture")]
    public async Task<IActionResult> UploadProfilePicture(IFormFile file)
    {
    var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")!);

    var user = await _db.Users.FindAsync(userId);
    if (user is null)
        return NotFound(new { success = false });

    if (file is null || file.Length == 0)
        return BadRequest(new { success = false, message = "No file uploaded." });

    var allowedTypes = new[] { "image/jpeg", "image/png", "image/webp" };
    if (!allowedTypes.Contains(file.ContentType))
        return BadRequest(new { success = false, message = "Only JPEG, PNG or WEBP images are allowed." });

    const long maxSizeBytes = 5 * 1024 * 1024; // 5 MB
    if (file.Length > maxSizeBytes)
        return BadRequest(new { success = false, message = "File must be under 5MB." });

    if (!string.IsNullOrEmpty(user.ProfileIcon))
    {
        var oldPath = Path.Combine("profilepicture", user.ProfileIcon);
        if (System.IO.File.Exists(oldPath))
            System.IO.File.Delete(oldPath);
    }
    // Generate a unique filename for the new profile picture and save it to the server.
    var extension = Path.GetExtension(file.FileName);
    var fileName = $"{userId}_{Guid.NewGuid()}{extension}";
    var savePath = Path.Combine("profilepicture", fileName);

    using (var stream = new FileStream(savePath, FileMode.Create))
    {
        await file.CopyToAsync(stream);
    }

    user.ProfileIcon = fileName;
    await _db.SaveChangesAsync();

    return Ok(new { success = true, profileIcon = fileName, url = $"/profilepicture/{fileName}" });
}
}