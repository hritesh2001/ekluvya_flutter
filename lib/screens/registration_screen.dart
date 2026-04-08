import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final ApiService apiService = ApiService();

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final emailController = TextEditingController();

  String? gender;
  String? preparingFor;
  DateTime? dob;
  File? image;

  bool loading = false;

  late String phone;

  final picker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    phone = args?['phone'] ?? "";
  }

  Future pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  String getGenderValue(String gender) {
    if (gender == "Male") return "1";
    if (gender == "Female") return "2";
    return "1";
  }

  void register() async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone missing. Please login again")),
      );
      return;
    }
    if (firstName.text.isEmpty ||
        lastName.text.isEmpty ||
        emailController.text.isEmpty ||
        gender == null ||
        preparingFor == null ||
        dob == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => loading = true);

    try {
      final res = await apiService.registerUser(
        firstName: firstName.text,
        lastName: lastName.text,
        email: emailController.text,
        phone: phone,
        gender: getGenderValue(gender!),
        preparingFor: preparingFor!,
        dob: dob!,
        image: image,
      );

      if (!mounted) return;

      setState(() => loading = false);

      if (res['statusCode'] == 200) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(res['message'] ?? "Failed")));
      }
    } catch (e) {
      setState(() => loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[200],

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// PROFILE IMAGE
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: image != null ? FileImage(image!) : null,
                    child: image == null
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.orange],
                        ),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// CARD
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(
                    colors: [Color(0xfff83600), Color(0xfff9a825)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "WHO’S LEARNING?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    buildField("FIRST NAME", controller: firstName),
                    buildField("LAST NAME", controller: lastName),
                    buildField("EMAIL", controller: emailController),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(1990),
                                lastDate: DateTime.now(),
                              );

                              if (picked != null) {
                                setState(() => dob = picked);
                              }
                            },
                            child: buildField(
                              dob == null
                                  ? "DOB"
                                  : "${dob!.day.toString().padLeft(2, '0')}"
                                        "${dob!.month.toString().padLeft(2, '0')}"
                                        "${dob!.year}",
                              enabled: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: buildDropdown(
                            hint: "GENDER",
                            value: gender,
                            items: ["Male", "Female"],
                            onChanged: (val) => setState(() => gender = val),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    buildDropdown(
                      hint: "PREPARING FOR",
                      value: preparingFor,
                      items: [
                        "IIT FOUNDATION",
                        "NEET FOUNDATION",
                        "INTEGRATED",
                        "PRIMARY",
                        "PRE-PRIMARY",
                      ],
                      onChanged: (val) => setState(() => preparingFor = val),
                    ),

                    const SizedBox(height: 20),

                    /// BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loading ? null : register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                            ),
                            child: loading
                                ? const CircularProgressIndicator()
                                : const Text(
                                    "SAVE",
                                    style: TextStyle(color: Colors.red),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/');
                            },
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                        child: const Text(
                          "SKIP FOR NOW, I’LL DO IT LATER",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildField(
    String hint, {
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: hint == "EMAIL"
            ? TextInputType.emailAddress
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        underline: const SizedBox(),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (val) => onChanged(val!),
      ),
    );
  }
}
