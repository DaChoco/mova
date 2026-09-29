namespace Mova.Api.Models;

public class User
{
    public int UserId { get; set; }
    public string StudentNumber { get; set; } = "";
    public string FirstName { get; set; } = "";
    public string Surname { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string? ProfileIcon { get; set; }
    public int? CarId { get; set; }
}