
//MODELS
// THESE ARE DATA CLASSES TO SIMPLIFY OUR REQUESTS BACK AND FORTH FOR THE FRONT END AND BACKEND
// C# 

class RegisterRequest {
  final String studentName;
  final String studentSurname;
  final String studentNumber;
  final String password;

  RegisterRequest({
    required this.studentName,
    required this.studentSurname,
    required this.studentNumber,
    required this.password
  });

  Map<String, dynamic> toJson() {
    return {
      'studentName': studentName,
      'studentSurname': studentSurname,
      'studentNumber': studentNumber,
      'password': password

    };
  }
}

class RegisterResponse {
  final String jwt;
  final bool success;

  RegisterResponse({
    required this.jwt,
    required this.success,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json){
    return RegisterResponse(jwt: json['jwt'], success: json['success']);
  }
}
