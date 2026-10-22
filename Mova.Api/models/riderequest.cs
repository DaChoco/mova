namespace Mova.Api.Models;

public class RideRequest
{
    public int RideRequestId { get; set; }

    public int RideId { get; set; }
    public Ride? Ride { get; set; }

    public int PassengerId { get; set; }
    public User? Passenger { get; set; }

    public string Status { get; set; } = "pending"; // pending, accepted, rejected, cancelled

    public double? Rating { get; set; }

    public DateTime RequestedAt { get; set; }
    public DateTime? RespondedAt { get; set; }
}