namespace Mova.Api.Dtos;

public record CreateRideRequest(
    double PickupLatitude,
    double PickupLongitude,
    string PickupAddress,
    double DestinationLatitude,
    double DestinationLongitude,
    string DestinationAddress,
    DateTime ScheduledFor,
    int AvailableSeats
);

public record RateRideRequest(double Rating);
public record AcceptPassengerRequest(int PassengerId);