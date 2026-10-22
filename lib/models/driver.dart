// Driver related Data classes

// WHEN THE RIDE IS GOING ON
class ActiveRide {
  final String rideId;
  final String status;
  final String origin;
  final String destination;
  final String? studentName;
  final String? vehicle;
  final String? availableSeats;

  ActiveRide({
    required this.rideId,
    required this.status,
    required this.origin,
    required this.destination,
    this.studentName,
    this.vehicle,
    this.availableSeats

  });

  factory ActiveRide.fromJson(Map<String, dynamic> json) {
    return ActiveRide(
      rideId: json['rideId'],
      status: json['status'],
      origin: json['origin'],
      destination: json['destination'],
      studentName: json['driverName'],
      vehicle: json['vehicle'],
      availableSeats: json['availableseats']
    );
  }
}

// LOCATION, VERY IMPORTANT
class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

//Status
enum DriverStatus {
  offline,
  online,
  busy,
  onTrip,
}

class DriverRating {
  final double averageRating;
  final double riderID;
  final double reviewerID;
  final int totalRatings;
  final String datetime;

  DriverRating({
    required this.averageRating,
    required this.riderID,
    required this.reviewerID,
    required this.totalRatings,
    required this.datetime,
  });
}

class DriverRide {
  final String rideId;
  final String studentName;
  final String pickup;
  final String destination;

  final String status;

  DriverRide({
    required this.rideId,
    required this.studentName,
    required this.pickup,
    required this.destination,
    required this.status,
  });
}