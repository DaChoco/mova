class User {
  final String userID;
  final String studentNumber;
  final String studentName;
  final String studentSurname;
  final String? carID;

  User({
    required this.userID,
    required this.studentNumber,
    required this.studentName,
    required this.studentSurname,
    this.carID,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userID: json['userId'],
      studentNumber: json['studentNumber'],
      studentName: json['firstName'],
      studentSurname: json['surname'],
    );
  }
}

// NOTIFS
class UserPreferences {
  final bool notificationsEnabled;
  final bool locationSharingEnabled;
  final String preferredPaymentMethod;

  UserPreferences({
    required this.notificationsEnabled,
    required this.locationSharingEnabled,
    required this.preferredPaymentMethod,
  });
}

// SAVED
class SavedLocation {
  final String locationId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  SavedLocation({
    required this.locationId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class UserRating {
  final double averageRating;
  final int numberOfRatings;

  UserRating({
    required this.averageRating,
    required this.numberOfRatings,
  });
}

class EmergencyContact {
  final String contactId;
  final String name;
  final String phoneNumber;
  final String relationship;

  EmergencyContact({
    required this.contactId,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
  });
}