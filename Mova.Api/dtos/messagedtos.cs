namespace Mova.Api.Dtos;

public record SendMessageRequest(string Message);

public class MessageDto
{
    public string MessageId { get; set; } = string.Empty;
    public int SenderId { get; set; } = 0;
    public string RideId { get; set; } = string.Empty;
    public string SenderType { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string SentAt { get; set; } = string.Empty;
    public bool IsRead { get; set; }
}