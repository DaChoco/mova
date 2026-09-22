class LoginRequest {
  final String studentNumber;
  final String password;

  LoginRequest({
    required this.studentNumber,
    required this.password
  });

  Map<String, dynamic> toJson() {
    return {
      'studentNumber': studentNumber,
      'password': password

    };
  }

  
}

class LoginResponse {
  final String jwt;
  final bool success;

  LoginResponse({
    required this.jwt,
    required this.success,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json){
    return LoginResponse(jwt: json['jwt'], success: json['success']);
  }}