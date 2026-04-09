import '../services/api_service.dart';
import 'dart:io';

class RegistrationViewModel {
  final ApiService api = ApiService();

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String gender,
    required String preparingFor,
    required DateTime dob,
    File? image,
  }) async {
    try {
      final res = await api.registerUser(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        gender: gender,
        preparingFor: preparingFor,
        dob: dob,
        image: image,
      );

      if (res?['statusCode'] == 200) {
        return {"success": true};
      } else {
        return {
          "success": false,
          "message": res?['message'] ?? "Registration failed",
        };
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}