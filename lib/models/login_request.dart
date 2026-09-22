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