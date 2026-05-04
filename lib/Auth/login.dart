import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Tambahkan Controller
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _obscureText = true;
  bool _isLoading = false; // Tambahkan loading state

  // FUNGSI KONEK KE SERVER
  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    // GANTI localhost menjadi 10.0.2.2 jika pakai emulator Android
    final url = Uri.parse('http://10.0.2.2:3000/api/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'identifier': _emailController.text.trim(), // Sesuai backend kamu
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Login Berhasil: ${data['token']}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Berhasil!'), backgroundColor: Colors.green),
        );
      } else {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Login Gagal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa konek ke server!'), backgroundColor: Colors.orange),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),

              // --- SECTION LOGO (LAYOUT ASLI) ---
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 180,
                      width: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.eco_rounded,
                          size: 100,
                          color: Colors.blue,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),
              const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 24),

              // --- FIELD EMAIL (LAYOUT ASLI) ---
              const Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController, // Controller terpasang
                decoration: InputDecoration(
                  hintText: 'rafihafizhnianggia@gmail.com',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- FIELD PASSWORD (LAYOUT ASLI) ---
              const Text(
                'Password',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController, // Controller terpasang
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: '************',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // --- REMEMBER ME & FORGOT PASSWORD (LAYOUT ASLI) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: Colors.blue,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value!),
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: Colors.lightBlue),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- BUTTON LOGIN (LAYOUT ASLI + FUNGSI) ---
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              ),

              const SizedBox(height: 30),

              // --- DIVIDER (LAYOUT ASLI) ---
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or Sign In with',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              // --- SOCIAL BUTTONS (LAYOUT ASLI) ---
              Row(
                children: [
                  Expanded(
                    child: _socialButton(
                      label: 'Facebook',
                      iconWidget: const Icon(
                        Icons.facebook,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _socialButton(
                      label: 'Google',
                      iconWidget: const Icon(Icons.g_mobiledata, color: Colors.red, size: 30),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // --- FOOTER (LAYOUT ASLI) ---
              Center(
                child: Wrap(
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Colors.lightBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({required String label, required Widget iconWidget}) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Color(0xFFEAECF0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: const Color(0xFFF9FAFB),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}