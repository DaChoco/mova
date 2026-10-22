namespace Mova.Api.Dtos;

public record RegisterRequest(string StudentName, string StudentSurname, string StudentNumber, string Password);
public record LoginRequest(string StudentNumber, string Password);
public record RefreshRequest(string RefreshToken);
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);
public record UpdateUserRequest(bool IsDriver);
public record UpdateProfilePictureRequest(string ProfilePictureUrl);