import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = "https://stg-ottapi.ekluvya.guru/users/api/v1";

  Future identifyUser(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/identify-user'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"identifier": phone}),
    );

    return jsonDecode(res.body);
  }

  Future sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/send-newOtp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"code": "91", "is_phone_verified": 0, "to": phone}),
    );

    return jsonDecode(res.body);
  }

  Future validateOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/validate-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"phone": phone, "otp": otp}),
    );

    return jsonDecode(res.body);
  }

  Future resendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/send-newOtp'),
      body: {'phone': phone},
    );

    return jsonDecode(res.body);
  }

  Future googleLogin(String idToken) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"google_auth_id": idToken}),
    );

    return jsonDecode(res.body);
  }

  Future getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.get(
      Uri.parse('https://stg-ottapi.ekluvya.guru/mediaview/api/v1/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return jsonDecode(res.body);
  }

  Future fetchCommonFeatures() async {
    final res = await http.get(
      Uri.parse('https://stg-ottapi.ekluvya.guru/mediaview/api/v1/common'),
    );

    return jsonDecode(res.body);
  }

  Future<dynamic> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String gender,
    required String preparingFor,
    required DateTime dob,
    File? image,
  }) async {
    var uri = Uri.parse('$baseUrl/auth/register');

    var request = http.MultipartRequest('POST', uri);

    request.fields.addAll({
      "first_name": firstName,
      "last_name": lastName,
      "email": email,
      "phone": phone,
      "gender": gender,
      "preparing_for": preparingFor,
      "dob":
          "${dob.day.toString().padLeft(2, '0')}/"
          "${dob.month.toString().padLeft(2, '0')}/"
          "${dob.year}",
      "country_code": "91",
    });

    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', image.path),
      );
    }

    var response = await request.send();

    /// ✅ THIS IS THE CORRECT PART
    var responseBody = await response.stream.bytesToString();

    final decoded = jsonDecode(responseBody);

    return decoded;
  }
}
