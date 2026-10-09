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
  final String messageID;
  final String rideID;
  final String senderID;
  final String senderType;
  final String message;
  final String datetime;
  final bool isRead;

  MessageRecieved({
    required this.messageID,
    required this.rideID,
    required this.senderID,
    required this.senderType,
    required this.message,
    required this.datetime,
    required this.isRead
  });

  factory MessageRecieved.fromJson(Map<String, dynamic> json) {
    return MessageRecieved(
      messageID: json['_id'] as String,
      rideID: json['rideId'] as String,
      senderID: json['senderId'] as String,
      senderType: json['senderType'] as String,
      message: json['message'] as String,
      datetime: json['sentAt'] as String,
      isRead: json['isRead'] as bool,
    );
  }
}

