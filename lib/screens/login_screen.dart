import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final ApiService apiService = ApiService();
  bool loading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();

      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;

      print("GOOGLE TOKEN: $idToken");

      if (idToken == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Google login failed")));
        return;
      }

      final res = await apiService.googleLogin(idToken);

      print("GOOGLE LOGIN RESPONSE: $res");

      if (!mounted) return;

      if (res['status'] == "success") {
        final token = res['response']['access_token'];

        // ✅ SAVE TOKEN
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Login failed")),
        );
      }
    } catch (e) {
      print("Google error: $e");
    }
  }

  void sendOtp() async {
    if (phoneController.text.length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid number")));
      return;
    }

    setState(() => loading = true);

    // STEP 1: identify user
    final identifyRes = await apiService.identifyUser(phoneController.text);

    print("IDENTIFY RESPONSE: $identifyRes");

    if (!mounted) return;

    if (identifyRes['status'] != "success") {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
      return;
    }

    bool exists = identifyRes['response']['exists'];

    // STEP 2: send OTP
    final res = await apiService.sendOtp(phoneController.text);

    print("SEND OTP RESPONSE: $res");

    if (!mounted) return;

    setState(() => loading = false);

    if (res['status'] == "success") {
      Navigator.pushNamed(
        context,
        '/otp',
        arguments: {'phone': phoneController.text, 'exists': exists},
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to send OTP")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ❌ Close Button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    if (Platform.isAndroid) {
                      SystemNavigator.pop();
                    } else {
                      exit(0);
                    }
                  },
                ),
              ),

              const SizedBox(height: 40),

              /// 📝 Title
              const Text(
                "Continue with mobile",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              /// 📄 Subtitle
              const Text(
                "Welcome back. Sign in & let’s get started.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(height: 40),

              /// 📱 Mobile Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text(
                      "+91",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const VerticalDivider(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Enter mobile number",
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// 🔘 Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Continue", style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 30),

              /// OR Divider
              Row(
                children: const [
                  Expanded(child: Divider(color: Colors.white70)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("OR", style: TextStyle(color: Colors.white)),
                  ),
                  Expanded(child: Divider(color: Colors.white70)),
                ],
              ),

              const SizedBox(height: 30),

              /// 🔵 Google Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: signInWithGoogle,
                  icon: Image.network(
                    "https://cdn-icons-png.flaticon.com/512/2991/2991148.png",
                    height: 20,
                  ),
                  label: const Text("Continue with Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
