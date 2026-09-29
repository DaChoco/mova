using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Mova.Api.Data;
using Mova.Api.Dtos;

namespace Mova.Api.Controllers;

[ApiController]
[Route("api/rides/{rideId}/messages")]
[Authorize]
public class MessagesController : ControllerBase
{
    private readonly AppDbContext _db;
    public MessagesController(AppDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetMessages(int rideId)
    {
        var messages = await _db.Messages
            .Where(m => m.RideId == rideId)
            .OrderBy(m => m.SentAt)
            .Select(m => new
            {
                rideID = m.RideId.ToString(),
                userID = m.UserId.ToString(),
                driverID = m.DriverId.ToString(),
                message = m.MessageText,
                datetime = m.SentAt.ToString("o"),
                isRead = m.IsRead
            })
            .ToListAsync();

        return Ok(new { success = true, messages });
    }

    [HttpPost]
    public async Task<IActionResult> PostMessage(int rideId, [FromBody] SendMessageRequest req)
    {
        // TODO: once the Ride model exists, look up the ride's userId/driverId here
        // and derive senderType from the logged-in user's claim, instead of trusting the client.
        return Ok(new { success = true });
    }
}