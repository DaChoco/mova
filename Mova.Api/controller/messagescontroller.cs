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


    [HttpGet]
    [Route("/api/messages/mine")]
    [Route("/api/chats")]
    public async Task<IActionResult> GetMyChats()
    {
    var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")!);

    var myMessages = await _mongo.Messages
        .Find(m => m.SenderId == currentUserId)
        .ToListAsync();

    var chats = myMessages
        .GroupBy(m => m.RideId)
        .Select(group =>
        {
            var lastMessage = group.OrderByDescending(m => m.SentAt).First();
            return new
            {
                rideId = group.Key,
                lastMessage = lastMessage.Message,
                lastMessageAt = lastMessage.SentAt.ToString("yyyy-MM-ddTHH:mm:ssZ"),
                lastSenderType = lastMessage.SenderType
            };
        })
        .OrderByDescending(c => c.lastMessageAt)
        .ToList();

    return Ok(new { success = true, chats });
    }
}