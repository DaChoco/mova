namespace Mova.Api.Models;

public class Message
{
    public int MessageId { get; set; }
    public int RideId { get; set; }
    public int UserId { get; set; }
    public int DriverId { get; set; }
    public string SenderType { get; set; } = ""; // "rider" or "driver" — see note below
    public string MessageText { get; set; } = "";
    public DateTime SentAt { get; set; }
    public bool IsRead { get; set; }
}