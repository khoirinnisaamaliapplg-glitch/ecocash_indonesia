import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/Auth/check_email.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ============================================================
  // CONTROLLER
  // ============================================================

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    final String name = _nameController.text.trim();

    final String username = _usernameController.text.trim().toLowerCase();

    final String email = _emailController.text.trim().toLowerCase();

    final String password = _passwordController.text;

    final String confirmPassword = _confirmPasswordController.text;

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (name.isEmpty) {
      _showMessage('Nama wajib diisi.', Colors.orange);
      return;
    }

    if (username.isEmpty) {
      _showMessage('Username wajib diisi.', Colors.orange);
      return;
    }

    if (email.isEmpty) {
      _showMessage('Email wajib diisi.', Colors.orange);
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Format email tidak valid.', Colors.orange);
      return;
    }

    if (password.isEmpty) {
      _showMessage('Password wajib diisi.', Colors.orange);
      return;
    }

    if (password.length < 6) {
      _showMessage('Password minimal 6 karakter.', Colors.orange);
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Konfirmasi password tidak sama.', Colors.orange);
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // PAYLOAD
      // ========================================================

      final Map<String, dynamic> payload = {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      };

      debugPrint('');
      debugPrint('======================================');
      debugPrint('REGISTER ECOCASH');
      debugPrint('URL      : ${ApiConfig.register}');
      debugPrint('NAME     : $name');
      debugPrint('USERNAME : $username');
      debugPrint('EMAIL    : $email');
      debugPrint('======================================');

      // ========================================================
      // REQUEST
      // ========================================================

      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint(
        'REGISTER STATUS : '
        '${response.statusCode}',
      );

      debugPrint(
        'REGISTER BODY   : '
        '${response.body}',
      );

      debugPrint('======================================');
      debugPrint('');

      // ========================================================
      // PARSE JSON
      // ========================================================

      dynamic responseData;

      try {
        responseData = jsonDecode(response.body);
      } catch (_) {
        responseData = null;
      }

      if (!mounted) return;

      // ========================================================
      // SUCCESS
      // ========================================================

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              return CheckEmailPage(email: email);
            },
          ),
        );

        return;
      }

      // ========================================================
      // ERROR
      // ========================================================

      String message = 'Registrasi gagal.';

      if (responseData is Map) {
        final dynamic serverMessage = responseData['message'];

        if (serverMessage != null &&
            serverMessage.toString().trim().isNotEmpty) {
          message = serverMessage.toString();
        }
      }

      _showMessage(message, Colors.red);
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('REGISTER ERROR: $e');
      debugPrint('$stackTrace');
      debugPrint('');

      if (!mounted) return;

      _showMessage('Tidak dapat terhubung ke server EcoCash.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool confirmPassword = false,
  }) {
    final bool obscure = isPassword
        ? (confirmPassword ? !_isConfirmPasswordVisible : !_isPasswordVisible)
        : false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),

              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          if (confirmPassword) {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          } else {
                            _isPasswordVisible = !_isPasswordVisible;
                          }
                        });
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),

      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),

            child: Padding(
              padding: const EdgeInsets.all(24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =================================================
                  // LOGO
                  // =================================================
                  Center(
                    child: Image.asset(
                      'assets/logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =================================================
                  // TITLE
                  // =================================================
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D2939),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Buat akun EcoCash Indonesia.',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),

                  const SizedBox(height: 30),

                  // =================================================
                  // NAME
                  // =================================================
                  _buildInputField(
                    label: 'Name',
                    hint: 'Nama lengkap',
                    controller: _nameController,
                  ),

                  // =================================================
                  // USERNAME
                  // =================================================
                  _buildInputField(
                    label: 'Username',
                    hint: 'Username',
                    controller: _usernameController,
                  ),

                  // =================================================
                  // EMAIL
                  // =================================================
                  _buildInputField(
                    label: 'Email',
                    hint: 'nama@email.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  // =================================================
                  // PASSWORD
                  // =================================================
                  _buildInputField(
                    label: 'Password',
                    hint: 'Password',
                    controller: _passwordController,
                    isPassword: true,
                  ),

                  // =================================================
                  // CONFIRM PASSWORD
                  // =================================================
                  _buildInputField(
                    label: 'Confirm Password',
                    hint: 'Ulangi password',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    confirmPassword: true,
                  ),

                  const SizedBox(height: 10),

                  // =================================================
                  // REGISTER BUTTON
                  // =================================================
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
