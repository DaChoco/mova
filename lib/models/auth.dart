//MODELS

// THESE ARE DATA CLASSES TO SIMPLIFY OUR REQUESTS BACK AND FORTH FOR THE FRONT END AND BACKEND

// C#

class LoginRequest {
  final String studentNumber;
  final String password;

  LoginRequest({required this.studentNumber, required this.password});

  Map<String, dynamic> toJson() {
    return {'studentNumber': studentNumber, 'password': password};
  }
}

class LoginResponse {
  final String jwt;
  final String refreshToken;
  final bool success;

  LoginResponse({
    required this.jwt,
    required this.refreshToken,
    required this.success,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      jwt: json['jwt'],
      refreshToken: json['refreshToken'],
      success: json['success'],
    );
  }
}

//-------------------------------------------------------

class RegisterRequest {
  final String studentName;
  final String studentSurname;
  final String studentNumber;
  final String password;

  RegisterRequest({
    required this.studentName,
    required this.studentSurname,
    required this.studentNumber,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentName': studentName,
      'studentSurname': studentSurname,
      'studentNumber': studentNumber,
      'password': password,
    };
  }
}

class RegisterResponse {
  final String jwt;
  final String refreshToken;
  final bool success;

  RegisterResponse({
    required this.jwt,
    required this.refreshToken,
    required this.success,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      jwt: json['jwt'],
      refreshToken: json['refreshToken'],
      success: json['success'],
    );
  }
}

//-------------------------------------------------------

class User {
  final int userId;
  final String studentNumber;
  final String firstName;
  final String surname;
  final bool isDriver;
  final int? carID;
  final String? profileIcon;

  User({
    required this.userId,
    required this.studentNumber,
    required this.firstName,
    required this.surname,
    required this.isDriver,
    this.carID,
    this.profileIcon,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'],
      studentNumber: json['studentNumber'],
      firstName: json['firstName'],
      surname: json['surname'],
      isDriver: json['isDriver'] ?? false,
      carID: json['carID'],
      profileIcon: json['profileIcon'],
    );
  }
}

//-------------------------------------------------------

class ChangePasswordRequest {
  final String currentPassword;
  final String newPassword;

  ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  };
}
