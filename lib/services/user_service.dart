import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class UserService {

  final String baseurl;

  UserService({
    required this.baseurl,
  });

  // /api/user/{1}

  Future<User>getUser(String userToken, String ID) async {
    final url = Uri.parse('$baseurl/api/user/$ID');
    final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $userToken'});

    if (response.statusCode == 200){
      final json = jsonDecode(response.body);
      return User.fromJson(json);
    }
    
    if (response.statusCode == 401) {
      throw Exception('Invalid or Expired User Token');
    }

    throw Exception(
      'Extraction failed failed. Server returned ${response.statusCode}',
    );

  }
//api/user/{}/rating
Future<UserRating> getUserRating(String userToken, String userID) async{
  final url = Uri.parse('$baseurl/api/user/$userID');

  final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $userToken'});

  if (response.statusCode == 200){
    final json = jsonDecode(response.body);
    return UserRating.fromJson(json);
  }
      throw Exception(
      'Failed to check rating. '
      'Status code: ${response.statusCode}',
    );

}
// api/user/{}/update

// /api/user/location/saved - POST
  Future<SavedLocation> addSavedLocation(String userToken) async{
    final url = Uri.parse('$baseurl/api/user/location/saved');
    final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $userToken'});

    if (response.statusCode == 200){
      final json = jsonDecode(response.body);
      return SavedLocation.fromJson(json);
      
    }

    throw Exception(
      'Failed to add location. '
      'Status code: ${response.statusCode}',
    );






  }
}