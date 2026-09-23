# USER ROUTES
/api/user/{1} - GET
SEND

{
    "TOKEN": XYXAAAAAAAAAAAAA
}
RECIEVE:
{
success: True
user:{
        "userId": 1,
        "studentNumber": "EDUV1234567",
        "firstName": "John",
        "surname": "Smith",
        "profileicon": "sisisisi.jpg
        "carId": "1"

    }
}

/api/user/update/1 - POST

# AUTH

/api/auth/register - POST

/api/auth/login - POST

# RIDE ROUTES

/api/rides - GET
From Flutter
{
  "pickupLatitude": -33.8765,
  "pickupLongitude": 18.6302,
  "pickupAddress": "Bellville Campus",
  "destinationLatitude": -33.9249,
  "destinationLongitude": 18.4241,
  "destinationAddress": "Cape Town CBD"
}

FROM C#
{
  "success": true,
  "ride": {
    "rideId": 152,
    "status": "searching_driver",
    "pickupAddress": "Bellville Campus",
    "destinationAddress": "Cape Town CBD",
    "estimatedFare": 145.50,
    "requestedAt": "2026-09-23T14:30:00Z"
  }
}

/api/rides/{rideid} - GET

/api/rides/active - GET

/api/rides/{rideid}/cancel - POST

/api/rides/{rideid}/accept - POST

/api/rides/{rideid}/reject - POST

/api/rides/{rideid}/start - POST

/api/rides/{rideid}/rate - POST

# MESSAGING

/api/rides/{rideId}/messages - GET

FROM C#
{
  "success": true,
  "messages": [
    {
      "messageId": 901,
      "senderId": 42,
      "senderType": "rider",
      "message": "I'm waiting near the main entrance.",
      "sentAt": "2026-09-23T14:38:12Z",
      "isRead": true
    },
    {
      "messageId": 902,
      "senderId": 27,
      "senderType": "driver",
      "message": "Okay, I'm almost there.",
      "sentAt": "2026-09-23T14:38:30Z",
      "isRead": true
    }
  ]
}

/api/rides/152/messages - POST [Appends the message json]
FROM FLUTTER
{
  "message": "I'm waiting near the main entrance."
}

FROM C#
{
  "success": true,
  "message": {
    "messageId": 903,
    "senderId": 42,
    "senderType": "rider",
    "message": "I'm waiting near the main entrance.",
    "sentAt": "2026-09-23T14:39:01Z",
    "isRead": false
  }
}

# DRIVERS
/api/drivers/{driverId} - GET
/api/drivers/nearby - GET
/api/drivers/{driverId}/location - GET