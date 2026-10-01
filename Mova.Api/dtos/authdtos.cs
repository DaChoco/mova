namespace Mova.Api.Dtos;

public record RegisterRequest(string StudentName, string StudentSurname, string StudentNumber, string Password);
public record LoginRequest(string StudentNumber, string Password);
public record RefreshRequest(string RefreshToken);
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);