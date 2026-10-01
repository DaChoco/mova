using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Mova.Api.Data;
using Mova.Api.Dtos;
using Mova.Api.Models;

namespace Mova.Api.Controllers;

[ApiController]
[Route("api/rides/{rideId}/messages")]
[Authorize]
public class MessagesController : ControllerBase
{
    private readonly MongoDbContext _mongo;

    public MessagesController(MongoDbContext mongo)
    {
        _mongo = mongo;
    }

    [HttpGet]
    public async Task<IActionResult> GetMessages(string rideId)
    {
        var messages = await _mongo.Messages
            .Find(m => m.RideId == rideId)
            .SortBy(m => m.SentAt)
            .ToListAsync();

        var result = messages.Select((m, index) => new
        {
            messageId = m.Id,
            senderId = m.SenderId,
            senderType = m.SenderType,
            message = m.Message,
            sentAt = m.SentAt.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            isRead = m.IsRead
        });

        return Ok(new { success = true, messages = result });
    }

    [HttpPost]
    public async Task<IActionResult> PostMessage(string rideId, [FromBody] SendMessageRequest req)
    {
        var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")!);

        // TODO: once Ride model exists, confirm currentUserId is actually the rider
        // or driver on this ride, and set senderType from that lookup instead of
        // assuming "rider" below.
        var doc = new MessageDocument
        {
            RideId = rideId,
            SenderId = currentUserId,
            SenderType = "rider", // placeholder until Ride model exists
            Message = req.Message,
            SentAt = DateTime.UtcNow,
            IsRead = false
        };

        await _mongo.Messages.InsertOneAsync(doc);

        return Ok(new
        {
            success = true,
            message = new
            {
                messageId = doc.Id,
                senderId = doc.SenderId,
                senderType = doc.SenderType,
                message = doc.Message,
                sentAt = doc.SentAt.ToString("yyyy-MM-ddTHH:mm:ssZ"),
                isRead = doc.IsRead
            }
        });
    }
}