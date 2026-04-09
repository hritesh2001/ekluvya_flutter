import '../services/api_service.dart';

class AuthViewModel {
  final ApiService api = ApiService();

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      if (phone.length < 10) {
        return {"success": false, "message": "Enter valid number"};
      }

      final identifyRes = await api.identifyUser(phone);

      if (identifyRes?['status'] != "success") {
        return {"success": false, "message": "Something went wrong"};
      }

      final exists = identifyRes?['response']?['exists'] ?? false;

      final res = await api.sendOtp(phone);

      if (res?['status'] == "success") {
        return {
          "success": true,
          "exists": exists,
        };
      } else {
        return {"success": false, "message": "Failed to send OTP"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp,
  ) async {
    try {
      if (otp.length < 6) {
        return {"success": false, "message": "Enter full OTP"};
      }

      final res = await api.validateOtp(phone, otp);

      if (res?['status'] == "success") {
        return {"success": true};
      } else {
        return {"success": false, "message": "Invalid OTP"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  Future<bool> resendOtp(String phone) async {
    try {
      final res = await api.sendOtp(phone);
      return res?['status'] == "success";
    } catch (e) {
      return false;
    }
  }
}