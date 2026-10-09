using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Mova.Api.Data;
using Mova.Api.Dtos;
using Mova.Api.Helpers;


namespace Mova.Api.Controllers;

// Controller for handling user-related endpoints, such as retrieving user information and managing profile pictures. EVERY endpoint requires authentication via JWT.

[ApiController]
[Route("api/user")]
[Authorize] // All endpoints in this controller require the user to be authenticated via JWT.
public class UserController : ControllerBase
{

    private readonly AppDbContext _db;
    private readonly SupabaseStorageService _storage;


    public UserController(AppDbContext db, SupabaseStorageService storage)
    {
        _db = db;
        _storage = storage;

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
            isDriver = user.IsDriver,
            carID = user.CarId,
            profileIcon = user.ProfileIcon != null
                ? $"{Request.Scheme}://{Request.Host}/profilepicture/{user.ProfileIcon}"
                : null
        }
    });
    }

    [HttpPost("update/{id}")]
    public async Task<IActionResult> Update(int id, UpdateUserRequest req)
{
    var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")!);

    if (id != currentUserId)
        return Forbid();

    var user = await _db.Users.FindAsync(id);

    if (user is null)
        return NotFound(new { success = false, message = "User account could not be found." });

    user.IsDriver = req.IsDriver;

    await _db.SaveChangesAsync();

    return Ok(new
    {
        success = true,
        message = "User updated successfully."
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
    [HttpPost("profile/upload")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadProfilePicture(
    [FromForm] IFormFile file)
    {
        var userIdClaim =
            User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub");

        if (!int.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new
            {
                success = false,
                message = "Invalid user identity."
            });
        }

        // Find the user
        var user = await _db.Users.FindAsync(userId);

        if (user is null)
        {
            return NotFound(new
            {
                success = false,
                message = "User not found."
            });
        }

        // Validate file
        if (file is null || file.Length == 0)
        {
            return BadRequest(new
            {
                success = false,
                message = "No file uploaded."
            });
        }

        var allowedTypes = new HashSet<string>(
            StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp"
    };

        if (!allowedTypes.Contains(file.ContentType))
        {
            return BadRequest(new
            {
                success = false,
                message = "Only JPEG, PNG or WEBP images are allowed."
            });
        }

        const long maxSizeBytes = 5 * 1024 * 1024;

        if (file.Length > maxSizeBytes)
        {
            return BadRequest(new
            {
                success = false,
                message = "File must not exceed 5MB."
            });
        }

        var extension = file.ContentType.ToLowerInvariant() switch
        {
            "image/jpeg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            _ => throw new InvalidOperationException(
                "Unsupported image type.")
        };

        var fileName = $"{Guid.NewGuid():N}{extension}";

        try
        {
            await using var stream = file.OpenReadStream();

            var profilePictureUrl =
                await _storage.UploadProfilePictureAsync(
                    bucketName: "user-icons",
                    userId: userId.ToString(),
                    fileName: fileName,
                    fileStream: stream,
                    contentType: file.ContentType);

            user.ProfileIcon = $"{userId}/{fileName}";

            await _db.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                profileIcon = user.ProfileIcon,
                url = profilePictureUrl
            });
        }
        catch (Exception)
        {
            // Log the exception on the server in production
            return StatusCode(500, new
            {
                success = false,
                message = "Failed to upload profile picture."
            });
        }
    }
}