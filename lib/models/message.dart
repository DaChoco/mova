// /api/rides/152/messages - POST [Appends the message: [{}, {}] json FIELD]. Messages are per ride only and conversations are not expected to be long per ride
//Send one {message: "AJSOJDOJODJOS"}
// Send to C#
class MessageSent{
  final String message;

  MessageSent({
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }

}

// /api/rides/152/messages - GET
//MessageRecieved[{}, {}] 
//Comes from C# ASP.net 
class MessageRecieved{
  final String rideID;
  final String userID;
  final String driverID;
  final String message;
  final String datetime;
  final bool isRead;

  MessageRecieved({
    required this.rideID,
    required this.userID,
    required this.driverID,
    required this.message,
    required this.datetime,
    required this.isRead
  });

  factory MessageRecieved.fromJson(Map<String, dynamic> json) {
    return MessageRecieved(
      rideID: json['rideID'] as String,
      userID: json['userID'] as String,
      driverID: json['driverID'] as String,
      message: json['message'] as String,
      datetime: json['datetime'] as String,
      isRead: json['isRead'] as bool,
    );
  }
}

