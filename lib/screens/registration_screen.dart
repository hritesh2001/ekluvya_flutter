import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../viewmodels/registration_viewmodel.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();

  String? _gender;
  String? _preparingFor;
  DateTime? _dob;
  File? _image;
  late String _phone;

  final _picker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _phone = args?['phone']?.toString() ?? '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _image = File(picked.path));
      }
    } catch (_) {
      _showSnack('Could not open gallery. Please try again.');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  String _genderValue(String g) => g == 'Female' ? '2' : '1';

  String _preparingForValue(String v) {
    const map = {
      'IIT FOUNDATION': 'IIT',
      'NEET FOUNDATION': 'NEET',
      'INTEGRATED': 'CBSE',
      'PRIMARY': 'PRIMARY',
      'PRE-PRIMARY': 'PREPRIMARY',
    };
    return map[v] ?? 'CBSE';
  }

  bool _validate() {
    if (_phone.isEmpty) {
      _showSnack('Phone missing. Please login again');
      return false;
    }
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      _showSnack('Please fill all fields');
      return false;
    }
    if (_gender == null) {
      _showSnack('Please select a gender');
      return false;
    }
    if (_preparingFor == null) {
      _showSnack('Please select what you are preparing for');
      return false;
    }
    if (_dob == null) {
      _showSnack('Please select your date of birth');
      return false;
    }
    return true;
  }

  Future<void> _register() async {
    if (!_validate()) return;

    final regVM = context.read<RegistrationViewModel>();
    final success = await regVM.register(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      phone: _phone,
      gender: _genderValue(_gender!),
      preparingFor: _preparingForValue(_preparingFor!),
      dob: _dob!,
      image: _image,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showSnack(regVM.errorMessage ?? 'Registration failed');
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              // Profile picture
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        _image != null ? FileImage(_image!) : null,
                    child: _image == null
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.orange],
                        ),
                      ),
                      child:
                          const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Form card
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
                        "WHO'S LEARNING?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildField('FIRST NAME', controller: _firstName),
                    _buildField('LAST NAME', controller: _lastName),
                    _buildField(
                      'EMAIL',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    // DOB + Gender row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: _buildField(
                              _dob == null
                                  ? 'DOB'
                                  : '${_dob!.day.toString().padLeft(2, '0')}/'
                                        '${_dob!.month.toString().padLeft(2, '0')}/'
                                        '${_dob!.year}',
                              enabled: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDropdown(
                            hint: 'GENDER',
                            value: _gender,
                            items: const ['Male', 'Female'],
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ),
                      ],
                    ),

                    _buildDropdown(
                      hint: 'PREPARING FOR',
                      value: _preparingFor,
                      items: const [
                        'IIT FOUNDATION',
                        'NEET FOUNDATION',
                        'INTEGRATED',
                        'PRIMARY',
                        'PRE-PRIMARY',
                      ],
                      onChanged: (v) => setState(() => _preparingFor = v),
                    ),

                    const SizedBox(height: 20),

                    // Action buttons — rebuilds only on loading state change
                    Consumer<RegistrationViewModel>(
                      builder: (context, regVM, _) => Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: regVM.isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white70,
                              ),
                              child: regVM.isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.red,
                                      ),
                                    )
                                  : const Text(
                                      'SAVE',
                                      style: TextStyle(color: Colors.red),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextButton(
                              onPressed: regVM.isLoading
                                  ? null
                                  : () => Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      ),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/home'),
                        child: const Text(
                          "SKIP FOR NOW, I'LL DO IT LATER",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable form widgets ─────────────────────────────────────────────────

  Widget _buildField(
    String hint, {
    TextEditingController? controller,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
