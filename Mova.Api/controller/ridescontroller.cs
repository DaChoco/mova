using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Mova.Api.Data;
using Mova.Api.Dtos;
using Mova.Api.Models;

namespace Mova.Api.Controllers;

[ApiController]
[Route("api/rides")]
[Authorize]
public class RidesController : ControllerBase
{
    private readonly AppDbContext _db;
    public RidesController(AppDbContext db) => _db = db;

    private int CurrentUserId() =>
        int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub")!);

    // Driver creates a ride
    [HttpPost]
    public async Task<IActionResult> Create(CreateRideRequest req)
{
    var driverId = CurrentUserId();
    var driver = await _db.Users.FindAsync(driverId);

    if (driver is null)
        return NotFound(new { success = false });

    if (!driver.IsDriver)
        return Forbid();

    if (req.AvailableSeats < 1)
        return BadRequest(new { success = false, message = "Available seats must be at least 1." });

    if (req.ScheduledFor <= DateTime.UtcNow)
        return BadRequest(new { success = false, message = "Scheduled time must be in the future." });

    var distanceKm = HaversineDistanceKm(
        req.PickupLatitude, req.PickupLongitude,
        req.DestinationLatitude, req.DestinationLongitude);

    var estimatedFare = Math.Round(20 + distanceKm * 8, 2);

    var ride = new Ride
    {
        DriverId = driverId,
        PickupLatitude = req.PickupLatitude,
        PickupLongitude = req.PickupLongitude,
        PickupAddress = req.PickupAddress,
        DestinationLatitude = req.DestinationLatitude,
        DestinationLongitude = req.DestinationLongitude,
        DestinationAddress = req.DestinationAddress,
        RequestedAt = DateTime.UtcNow,
        Status = "searching_driver",
        AvailableSeats = req.AvailableSeats,
        ScheduledFor = req.ScheduledFor,
        EstimatedFare = estimatedFare
       
    };

    _db.Rides.Add(ride);
    await _db.SaveChangesAsync();

    return Ok(new { success = true, ride = ToDto(ride) });
}
    [HttpGet("{rideId}")]
    public async Task<IActionResult> GetById(int rideId)
    {
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null)
            return NotFound(new { success = false });

        var userId = CurrentUserId();
        var isDriver = ride.DriverId == userId;
        var isPassenger = await _db.RideRequests.AnyAsync(rr => rr.RideId == rideId && rr.PassengerId == userId);

        if (!isDriver && !isPassenger)
            return Forbid();

        return Ok(new { success = true, ride = ToDto(ride) });
    }

    // Browse open rides with free seats (for passengers)
   [HttpGet("available")]
    public async Task<IActionResult> GetAvailable()
    {
        var userId = CurrentUserId();

        var rejectedRideIds = await _db.RideRequests
            .Where(rr => rr.PassengerId == userId && rr.Status == "rejected")
            .Select(rr => rr.RideId)
            .ToListAsync();

        var rides = await _db.Rides
            .Where(r => r.Status == "searching_driver"
                    && r.ScheduledFor > DateTime.UtcNow
                    && !rejectedRideIds.Contains(r.RideId))
            .OrderBy(r => r.ScheduledFor)
            .ToListAsync();

        var result = new List<object>();
        foreach (var ride in rides)
        {
            var acceptedCount = await _db.RideRequests
                .CountAsync(rr => rr.RideId == ride.RideId && rr.Status == "accepted");
            if (acceptedCount < ride.AvailableSeats)
                result.Add(ToDto(ride));
        }

        return Ok(new { success = true, rides = result });
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetActive()
    {
        var userId = CurrentUserId();
        var activeStatuses = new[] { "searching_driver", "in_progress" };

        var driverRide = await _db.Rides
            .Where(r => r.DriverId == userId && activeStatuses.Contains(r.Status))
            .OrderByDescending(r => r.ScheduledFor)
            .FirstOrDefaultAsync();

        if (driverRide is not null)
            return Ok(new { success = true, ride = ToDto(driverRide) });

        var passengerRideId = await _db.RideRequests
            .Where(rr => rr.PassengerId == userId && rr.Status == "accepted")
            .Join(_db.Rides.Where(r => activeStatuses.Contains(r.Status)),
                  rr => rr.RideId, r => r.RideId, (rr, r) => r)
            .OrderByDescending(r => r.RequestedAt)
            .FirstOrDefaultAsync();

        return Ok(new { success = true, ride = passengerRideId is null ? null : ToDto(passengerRideId) });
    }

    // Passenger requests to join a ride
    [HttpPost("{rideId}/request")]
    public async Task<IActionResult> RequestToJoin(int rideId)
    {
        var passengerId = CurrentUserId();
        var passenger = await _db.Users.FindAsync(passengerId);
        if (passenger is null) return NotFound(new { success = false });

        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        if (ride.DriverId == passengerId)
            return BadRequest(new { success = false, message = "You cannot join your own ride." });

        if (ride.Status != "searching_driver")
            return BadRequest(new { success = false, message = "This ride is no longer open to requests." });

        if (ride.ScheduledFor <= DateTime.UtcNow)
            return BadRequest(new { success = false, message = "This ride's scheduled time has already passed." });

        var alreadyRequested = await _db.RideRequests
            .AnyAsync(rr => rr.RideId == rideId && rr.PassengerId == passengerId);
        if (alreadyRequested)
            return BadRequest(new { success = false, message = "You already requested this ride." });

        var acceptedCount = await _db.RideRequests
            .CountAsync(rr => rr.RideId == rideId && rr.Status == "accepted");
        if (acceptedCount >= ride.AvailableSeats)
            return BadRequest(new { success = false, message = "This ride is full." });

        var request = new RideRequest
        {
            RideId = rideId,
            PassengerId = passengerId,
            Status = "pending",
            RequestedAt = DateTime.UtcNow
        };
        _db.RideRequests.Add(request);
        await _db.SaveChangesAsync();

        return Ok(new { success = true, requestId = request.RideRequestId, status = request.Status });
    }

    // Driver accepts a specific passenger's request
    // Contract shape kept as POST /api/rides/{rideId}/accept — pass passengerId in the body
    [HttpPost("{rideId}/accept")]
    public async Task<IActionResult> Accept(int rideId, [FromBody] AcceptPassengerRequest req)
    {
        var driverId = CurrentUserId();
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        if (ride.DriverId != driverId)
            return Forbid();

        var request = await _db.RideRequests
            .FirstOrDefaultAsync(rr => rr.RideId == rideId && rr.PassengerId == req.PassengerId);
        if (request is null)
            return NotFound(new { success = false, message = "No request from this passenger." });

        if (request.Status != "pending")
            return BadRequest(new { success = false, message = $"Request is already {request.Status}." });

        var acceptedCount = await _db.RideRequests
            .CountAsync(rr => rr.RideId == rideId && rr.Status == "accepted");
        if (acceptedCount >= ride.AvailableSeats)
            return BadRequest(new { success = false, message = "No seats remaining." });

        request.Status = "accepted";
        request.RespondedAt = DateTime.UtcNow;

        acceptedCount++;
        if (acceptedCount >= ride.AvailableSeats)
            ride.Status = "in_progress"; // fully booked — adjust if you want a separate "full" status

        await _db.SaveChangesAsync();

        return Ok(new { success = true, requestId = request.RideRequestId, status = request.Status });
    }

    // Driver rejects a specific passenger's request
    [HttpPost("{rideId}/reject")]
    public async Task<IActionResult> Reject(int rideId, [FromBody] AcceptPassengerRequest req)
    {
        var driverId = CurrentUserId();
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        if (ride.DriverId != driverId)
            return Forbid();

        var request = await _db.RideRequests
            .FirstOrDefaultAsync(rr => rr.RideId == rideId && rr.PassengerId == req.PassengerId);
        if (request is null)
            return NotFound(new { success = false, message = "No request from this passenger." });

        request.Status = "rejected";
        request.RespondedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { success = true, requestId = request.RideRequestId, status = request.Status });
    }

    [HttpPost("{rideId}/cancel")]
    public async Task<IActionResult> Cancel(int rideId)
    {
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        var userId = CurrentUserId();
        var isDriver = ride.DriverId == userId;
        var isAcceptedPassenger = await _db.RideRequests
            .AnyAsync(rr => rr.RideId == rideId && rr.PassengerId == userId && rr.Status == "accepted");

        if (!isDriver && !isAcceptedPassenger)
            return Forbid();

        if (ride.Status is "completed" or "cancelled")
            return BadRequest(new { success = false, message = $"Ride is already {ride.Status}." });

        if (isDriver)
        {
            // Driver cancelling cancels the whole ride for everyone
            ride.Status = "cancelled";
            ride.CancelledAt = DateTime.UtcNow;
        }
        else
        {
            // Passenger cancelling just drops their own seat
            var request = await _db.RideRequests
                .FirstAsync(rr => rr.RideId == rideId && rr.PassengerId == userId);
            request.Status = "cancelled";
            request.RespondedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();
        return Ok(new { success = true, ride = ToDto(ride) });
    }

    [HttpPost("{rideId}/start")]
    public async Task<IActionResult> Start(int rideId)
    {
        var driverId = CurrentUserId();
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        if (ride.DriverId != driverId)
            return Forbid();

        ride.Status = "in_progress";
        ride.StartedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { success = true, ride = ToDto(ride) });
    }

    [HttpPost("{rideId}/complete")]
    public async Task<IActionResult> Complete(int rideId)
    {
        var driverId = CurrentUserId();
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        if (ride.DriverId != driverId)
            return Forbid();

        if (ride.Status != "in_progress")
            return BadRequest(new { success = false, message = "Ride is not in progress." });

        ride.Status = "completed";
        ride.CompletedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { success = true, ride = ToDto(ride) });
    }

    // Passenger rates the driver for a completed ride they took
    [HttpPost("{rideId}/rate")]
    public async Task<IActionResult> Rate(int rideId, RateRideRequest req)
    {
        var passengerId = CurrentUserId();
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        if (ride.Status != "completed")
            return BadRequest(new { success = false, message = "Only completed rides can be rated." });

        var request = await _db.RideRequests
            .FirstOrDefaultAsync(rr => rr.RideId == rideId && rr.PassengerId == passengerId && rr.Status == "accepted");
        if (request is null)
            return Forbid();

        if (req.Rating is < 1 or > 5)
            return BadRequest(new { success = false, message = "Rating must be between 1 and 5." });

        request.Rating = req.Rating;
        await _db.SaveChangesAsync();

        return Ok(new { success = true, message = "Rating submitted." });
    }

    // Driver views pending requests for their ride
    [HttpGet("{rideId}/requests")]
    public async Task<IActionResult> GetRequests(int rideId)
    {
        var driverId = CurrentUserId();
        var ride = await _db.Rides.FindAsync(rideId);
        if (ride is null) return NotFound(new { success = false });

        if (ride.DriverId != driverId)
            return Forbid();

        var requests = await _db.RideRequests
            .Where(rr => rr.RideId == rideId)
            .Include(rr => rr.Passenger)
            .Select(rr => new
            {
                requestId = rr.RideRequestId,
                passengerId = rr.PassengerId,
                passengerName = rr.Passenger!.FirstName + " " + rr.Passenger.Surname,
                status = rr.Status,
                requestedAt = rr.RequestedAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
            })
            .ToListAsync();

        return Ok(new { success = true, requests });
    }

    private static double HaversineDistanceKm(double lat1, double lon1, double lat2, double lon2)
    {
        const double R = 6371;
        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return R * c;
    }

    private static double ToRad(double deg) => deg * Math.PI / 180;

    private static object ToDto(Ride r) => new
    {
        rideId = r.RideId,
        status = r.Status,
        pickupAddress = r.PickupAddress,
        destinationAddress = r.DestinationAddress,
        availableSeats = r.AvailableSeats,
        scheduledFor = r.ScheduledFor.ToString("yyyy-MM-ddTHH:mm:ssZ"),
        estimatedFare = r.EstimatedFare,
        requestedAt = r.RequestedAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
    };
}