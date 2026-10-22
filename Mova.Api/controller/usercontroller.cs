
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Mova.Api.Data;
using Mova.Api.Dtos;
using Mova.Api.Helpers;

namespace Mova.Api.Controllers;

// Controller for handling user-related endpoints, such as retrieving user
// information and managing profile pictures. All endpoints require JWT authentication.

[ApiController]
[Route("api/user")]
[Authorize]
public class UserController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly SupabaseStorageService _storage;
    private readonly IConfiguration _configuration;

    public UserController(
        AppDbContext db,
        SupabaseStorageService storage,
        IConfiguration configuration)
    {
        _db = db;
        _storage = storage;
        _configuration = configuration;
    }

    // Retrieves user information based on the provided user ID.
    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id)
    {
        var user = await _db.Users.FindAsync(id);

        if (user is null)
        {
            return NotFound(new { success = false });
        }

        // Clean the configured Supabase URL.
        // This handles values such as "https://example.supabase.co/;"
        var supabaseUrl = _configuration["SUPABASE_URL"]?
            .Trim()
            .TrimEnd('/', ';');

        // Remove any trailing separators left by unusual configuration values.
        while (!string.IsNullOrEmpty(supabaseUrl) &&
               (supabaseUrl.EndsWith('/') || supabaseUrl.EndsWith(';')))
        {
            supabaseUrl = supabaseUrl[..^1];
        }

        var profileIconUrl = !string.IsNullOrWhiteSpace(user.ProfileIcon)
            && !string.IsNullOrWhiteSpace(supabaseUrl)
                ? $"{supabaseUrl}/storage/v1/object/public/user-icons/{user.ProfileIcon.TrimStart('/')}"
                : null;

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
                profileIcon = user.ProfileIcon,
                profileIconUrl
            }
        });
    }

    [HttpPost("update/{id}")]
    public async Task<IActionResult> Update(int id, UpdateUserRequest req)
    {
        var currentUserIdClaim =
            User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub");

        if (!int.TryParse(currentUserIdClaim, out var currentUserId))
        {
            return Unauthorized(new
            {
                success = false,
                message = "Invalid user identity."
            });
        }

        if (id != currentUserId)
        {
            return Forbid();
        }

        var user = await _db.Users.FindAsync(id);

        if (user is null)
        {
            return NotFound(new
            {
                success = false,
                message = "User account could not be found."
            });
        }

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

        var user = await _db.Users.FindAsync(userId);

        if (user is null)
        {
            return NotFound(new { success = false });
        }

        if (!BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash))
        {
            return Unauthorized(new
            {
                success = false,
                message = "Current password is incorrect."
            });
        }

        if (string.IsNullOrWhiteSpace(req.NewPassword)
            || req.NewPassword.Length < 6)
        {
            return BadRequest(new
            {
                success = false,
                message = "New password must be at least 6 characters."
            });
        }

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);

        
        await _db.SaveChangesAsync();
        // Revoke all active refresh tokens for the user after changing the password
        var activeTokens = await _db.RefreshTokens
            .Where(rt => rt.UserId == userId && rt.RevokedAt == null)
            .ToListAsync();

        foreach (var token in activeTokens)
        {
            token.RevokedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();

        return Ok(new
        {
            success = true,
            message = "Password changed successfully."
        });
    }

    // Endpoint for uploading a user's profile picture. Accepts a multipart/form-data request containing the image file.
    [HttpPost("profile/upload")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadProfilePicture(IFormFile file)
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

        var user = await _db.Users.FindAsync(userId);

        if (user is null)
        {
            return NotFound(new
            {
                success = false,
                message = "User not found."
            });
        }

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
            // Upload the profile picture to Supabase storage
            var profilePictureUrl =
                await _storage.UploadProfilePictureAsync(
                    bucketName: "user-icons",
                    userId: userId.ToString(),
                    fileName: fileName,
                    fileStream: stream,
                    contentType: file.ContentType);

            user.ProfileIcon = $"{userId}/{fileName}";

            // Save the updated profile icon path to the database
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
            return StatusCode(500, new
            {
                success = false,
                message = "An error occurred while uploading the profile picture."
            });
        }
    }
}
