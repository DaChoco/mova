using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Mova.Api.Models;

[BsonIgnoreExtraElements]
public class MessageDocument
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    public string RideId { get; set; } = "";
    public int SenderId { get; set; }
    public string SenderType { get; set; } = "";
    public string Message { get; set; } = "";
    public DateTime SentAt { get; set; }
    public bool IsRead { get; set; }
}