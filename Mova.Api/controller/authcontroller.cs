using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Mova.Api.Data;
using Mova.Api.Dtos;
using Mova.Api.Models;

namespace Mova.Api.Controllers;


/// Controller for handling authentication-related endpoints.  
[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _config;

    public AuthController(AppDbContext db, IConfiguration config)
    {
        _db = db;
        _config = config;
    }
/// Registers a new user and returns a JWT and refresh token upon successful registration.
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest req)
    {
        if (await _db.Users.AnyAsync(u => u.StudentNumber == req.StudentNumber))
            return Conflict(new { success = false, message = "Student number already registered." });

        var user = new User
        {
            StudentNumber = req.StudentNumber,
            FirstName = req.StudentName,
            Surname = req.StudentSurname,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password)
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var (_, plainRefreshToken) = await IssueRefreshToken(user.UserId);

        return Ok(new
        {
            success = true,
            jwt = CreateAccessToken(user),
            refreshToken = plainRefreshToken,
            user = ToDto(user)
        });
    }
/// Logs in an existing user and returns a JWT and refresh token upon successful authentication.
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest req)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.StudentNumber == req.StudentNumber);

        if (user is null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            return Unauthorized(new { success = false, message = "Invalid credentials." });

        var (_, plainRefreshToken) = await IssueRefreshToken(user.UserId);

        return Ok(new
        {
            success = true,
            jwt = CreateAccessToken(user),
            refreshToken = plainRefreshToken,
            user = ToDto(user)
        });
    }


    /// Refreshes the access token using a valid refresh token.
    
    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh(RefreshRequest req)
    {
        var incomingHash = HashToken(req.RefreshToken);

        var existing = await _db.RefreshTokens
            .Include(rt => rt.User)
            .FirstOrDefaultAsync(rt => rt.TokenHash == incomingHash);

        if (existing is null || !existing.IsActive)
            return Unauthorized(new { success = false, message = "Invalid or expired refresh token." });

        // Rotation: revoke the used one, issue a brand new pair
        existing.RevokedAt = DateTime.UtcNow;
        var (_, newPlainToken) = await IssueRefreshToken(existing.UserId);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            success = true,
            jwt = CreateAccessToken(existing.User!),
            refreshToken = newPlainToken
        });
    }

/// Logs out the user by revoking the provided refresh token.
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(RefreshRequest req)
    {
        var incomingHash = HashToken(req.RefreshToken);

        var existing = await _db.RefreshTokens.FirstOrDefaultAsync(rt => rt.TokenHash == incomingHash);
        if (existing is not null)
        {
            existing.RevokedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }
        return Ok(new { success = true });
    }

/// Generates refresh token for the user, stores its hash in the database, and returns the plain token to be sent to the client.
    private async Task<(RefreshToken entity, string plainToken)> IssueRefreshToken(int userId)
    {
        var days = double.Parse(_config["Jwt:RefreshTokenExpiryDays"]!);
        var plainToken = GenerateSecureToken();

        var entity = new RefreshToken
        {
            TokenHash = HashToken(plainToken),
            UserId = userId,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(days)
        };

        _db.RefreshTokens.Add(entity);
        await _db.SaveChangesAsync();

        return (entity, plainToken); // plainToken is sent to the client, never stored
    }

    private static string GenerateSecureToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(64);
        return Convert.ToBase64String(bytes);
    }

    private static string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToBase64String(bytes);
    }
    /// Creates a JWT access token for the authenticated user.
    private string CreateAccessToken(User user)
    {
        var jwt = _config.GetSection("Jwt");
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Key"]!));

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new Claim("studentNumber", user.StudentNumber)
        };

        var token = new JwtSecurityToken(
            issuer: jwt["Issuer"],
            audience: jwt["Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(double.Parse(jwt["ExpiryMinutes"]!)),
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
// Converts a User entity to a DTO for API responses.
   private static object ToDto(User u) => new
{
    userId = u.UserId,
    studentNumber = u.StudentNumber,
    firstName = u.FirstName,
    surname = u.Surname,
    carID = u.CarId,
    isDriver = u.IsDriver
};
}