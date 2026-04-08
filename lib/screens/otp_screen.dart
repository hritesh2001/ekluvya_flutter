import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final ApiService apiService = ApiService();

  late String phone;
  late bool exists;

  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  bool loading = false;
  int timer = 30;
  bool isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map<String, dynamic>) {
        phone = args['phone'] ?? '';
        exists = args['exists'] ?? false;
      } else {
        phone = '';
        exists = false;
      }

      startTimer();
      isInitialized = true;
    }
  }

  void startTimer() {
    timer = 30;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted || timer == 0) return false;

      setState(() {
        timer--;
      });

      return true;
    });
  }

  String getOtp() {
    return controllers.map((c) => c.text).join();
  }

  void verifyOtp() async {
    if (getOtp().length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter full OTP")));
      return;
    }

    setState(() => loading = true);

    try {
      final res = await apiService.validateOtp(phone, getOtp());

      print("VERIFY OTP RESPONSE: $res");

      if (!mounted) return;

      if (res['status'] == "success") {
        if (exists) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/register',
            arguments: {'phone': phone},
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      }
    } catch (e) {
      print("REGISTER ERROR: $e"); // 👈 ADD THIS

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void resendOtp() async {
    try {
      await apiService.sendOtp(phone);
      startTimer();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("OTP resent")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to resend OTP")));
    }
  }

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget otpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: controllers[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20),
        decoration: InputDecoration(
          counterText: "",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            const Text(
              "Enter 6-digit code",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              "Code sent to +91 $phone",
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 10),

            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                "Change number",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, otpBox),
            ),

            const SizedBox(height: 20),

            Center(
              child: timer > 0
                  ? Text("Resend OTP in 00:${timer.toString().padLeft(2, '0')}")
                  : TextButton(
                      onPressed: resendOtp,
                      child: const Text("Resend OTP"),
                    ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Verify", style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
