using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Mova.Api.Data;
using Mova.Api.Dtos;
using Mova.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Mova.Api.Controllers;

[ApiController]
[Route("api/rides/{rideId}/messages")]
[Authorize]
public class MessagesController : ControllerBase
{
    private readonly MongoDbContext _mongo;
    private readonly AppDbContext _db;

    public MessagesController(MongoDbContext mongo, AppDbContext db)
    {
        _mongo = mongo;
        _db = db;
    }

 

    [HttpGet]
    public async Task<IActionResult> GetMessages(string rideId)
    {
        var messages = await _mongo.Messages
            .Find(m => m.RideId == rideId)
            .SortBy(m => m.SentAt)
            .ToListAsync();

        var result = messages.Select(m => new MessageDto
        {
            MessageId = m.Id,
            RideId = m.RideId,
            SenderId = m.SenderId,
            SenderType = m.SenderType ?? string.Empty,
            Message = m.Message,
            SentAt = m.SentAt.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            IsRead = m.IsRead
        });

        return Ok(new { success = true, messages = result });
    }

    [HttpPost]
    public async Task<IActionResult> PostMessage(string rideId, [FromBody] SendMessageRequest req)
    {
        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")!;

        // TODO: once Ride model exists, confirm currentUserId is actually the rider
        // or driver on this ride, and set senderType from that lookup instead of
        // assuming "rider" below.
        var doc = new MessageDocument
        {
            RideId = rideId,
            SenderId = int.Parse(currentUserId),
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

    [HttpPatch("{messageId}/read")]
    public async Task<IActionResult> MarkMessageAsRead(
    string rideId,
    string messageId)
    {
        var filter = Builders<MessageDocument>.Filter.And(
            Builders<MessageDocument>.Filter.Eq(m => m.Id, messageId),
            Builders<MessageDocument>.Filter.Eq(m => m.RideId, rideId)
        );

        var update = Builders<MessageDocument>.Update
            .Set(m => m.IsRead, true);

        var result = await _mongo.Messages.UpdateOneAsync(
            filter,
            update
        );

        if (result.MatchedCount == 0)
        {
            return NotFound(new
            {
                success = false,
                message = "Message not found."
            });
        }

        return Ok(new
        {
            success = true,
            messageId = messageId,
            isRead = true
        });
    }


    [HttpGet]
    [Route("/api/messages/mine")]
    [Route("/api/chats")]

public async Task<IActionResult> GetMyChats()
{
    var currentUserIdValue =
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub");

    if (!int.TryParse(currentUserIdValue, out var currentUserId))
    {
        return Unauthorized(new
        {
            success = false,
            message = "Invalid user ID."
        });
    }

    // Find rides where the current user is the driver.
    var driverRideIds = await _db.Rides
        .Where(r => r.DriverId == currentUserId)
        .Select(r => r.RideId)
        .ToListAsync();

    // Find rides where the current user is an accepted passenger.
    var passengerRideIds = await _db.RideRequests
        .Where(rr =>
            rr.PassengerId == currentUserId &&
            rr.Status == "accepted")
        .Select(rr => rr.RideId)
        .ToListAsync();

    var rideIds = driverRideIds
        .Union(passengerRideIds)
        .Select(id => id.ToString())
        .ToList();

    if (rideIds.Count == 0)
    {
        return Ok(new { success = true, chats = new object[0] });
    }

    // Load messages for rides the current user participates in.
    var filter = Builders<MessageDocument>.Filter.In(
        m => m.RideId,
        rideIds
    );

    var messages = await _mongo.Messages
        .Find(filter)
        .SortByDescending(m => m.SentAt)
        .ToListAsync();

    var chats = new List<object>();

    foreach (var group in messages.GroupBy(m => m.RideId))
    {
        if (!int.TryParse(group.Key, out var rideId))
            continue;

        var ride = await _db.Rides
            .Include(r => r.Driver)
            .FirstOrDefaultAsync(r => r.RideId == rideId);

        if (ride == null)
            continue;

        int otherUserId;

        if (ride.DriverId == currentUserId)
        {
            // For a driver, prefer the most recent message
            // sent by another participant.
            var otherMessage = group
                .FirstOrDefault(m => m.SenderId != currentUserId);

            if (otherMessage != null)
            {
                otherUserId = otherMessage.SenderId;
            }
            else
            {
                // If nobody else has sent a message yet,
                // use the first accepted passenger.
                var passenger = await _db.RideRequests
                    .Where(rr =>
                        rr.RideId == rideId &&
                        rr.Status == "accepted")
                    .OrderBy(rr => rr.RideRequestId)
                    .FirstOrDefaultAsync();

                if (passenger == null)
                    continue;

                otherUserId = passenger.PassengerId;
            }
        }
        else
        {
            // For a passenger, the other participant is the driver.
            otherUserId = ride.DriverId;
        }

        var otherUser = await _db.Users
            .FindAsync(otherUserId);

        if (otherUser == null)
            continue;

        var lastMessage = group
            .OrderByDescending(m => m.SentAt)
            .First();

        chats.Add(new
        {
            rideId = group.Key,
            otherUserId = otherUserId,
            otherUserName =
                $"{otherUser.FirstName} {otherUser.Surname}".Trim(),
            lastMessage = lastMessage.Message,
            lastMessageAt =
                lastMessage.SentAt.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            lastSenderType = lastMessage.SenderType
        });
    }

    return Ok(new
    {
        success = true,
        chats = chats
            .OrderByDescending(c =>
                ((dynamic)c).lastMessageAt)
            .ToList()
    });
}

}