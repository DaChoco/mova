namespace Mova.Api.Models;

public class Ride
{
    public int RideId { get; set; }

    public int DriverId { get; set; }
    public User? Driver { get; set; }

    public double PickupLatitude { get; set; }
    public double PickupLongitude { get; set; }
    public string PickupAddress { get; set; } = "";

    public double DestinationLatitude { get; set; }
    public double DestinationLongitude { get; set; }
    public string DestinationAddress { get; set; } = "";

    public DateTime ScheduledFor { get; set; }

    public string Status { get; set; } = "searching_driver"; // kept name for contract compatibility; means "open for requests"
    public int AvailableSeats { get; set; }

    public double EstimatedFare { get; set; }

    public DateTime RequestedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime? CancelledAt { get; set; }
}