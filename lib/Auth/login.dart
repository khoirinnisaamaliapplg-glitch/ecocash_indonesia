import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:ecocash_indonesia/home.dart';
import 'package:ecocash_indonesia/Auth/registrasi.dart';
import 'package:ecocash_indonesia/Auth/forgot_password.dart';
import 'package:ecocash_indonesia/ipconfig.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // CONTROLLER
  // ============================================================

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _rememberMe = true;
  bool _obscureText = true;
  bool _isLoading = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    final String identifier = _emailController.text.trim();

    final String password = _passwordController.text;

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (identifier.isEmpty || password.isEmpty) {
      _showSnackBar('Email/Username dan Password wajib diisi', Colors.orange);

      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('');
      debugPrint('========================================');
      debugPrint('LOGIN ECOCASH');
      debugPrint('URL        : ${ApiConfig.login}');
      debugPrint('IDENTIFIER : $identifier');
      debugPrint('========================================');

      // ========================================================
      // REQUEST LOGIN
      // ========================================================

      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );

      debugPrint('LOGIN STATUS : ${response.statusCode}');

      debugPrint('LOGIN BODY   : ${response.body}');

      debugPrint('========================================');
      debugPrint('');

      // ========================================================
      // PARSE JSON
      // ========================================================

      dynamic responseData;

      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        debugPrint('Response login bukan JSON: $e');

        if (!mounted) return;

        _showSnackBar('Response server tidak valid.', Colors.red);

        return;
      }

      // ========================================================
      // LOGIN SUCCESS
      // ========================================================

      if (response.statusCode == 200) {
        final dynamic data = responseData['data'];

        if (data == null || data is! Map) {
          if (!mounted) return;

          _showSnackBar('Data login tidak ditemukan.', Colors.red);

          return;
        }

        // ======================================================
        // GET TOKEN
        // ======================================================

        final String? token = data['token']?.toString();

        if (token == null || token.trim().isEmpty) {
          if (!mounted) return;

          _showSnackBar('Token login tidak ditemukan.', Colors.red);

          return;
        }

        // ======================================================
        // SAVE TOKEN
        // ======================================================

        ApiConfig.setToken(token);

        debugPrint('');
        debugPrint('========== TOKEN LOGIN ==========');
        debugPrint('TOKEN SAVED : ${ApiConfig.hasToken}');
        debugPrint('TOKEN LENGTH: ${ApiConfig.userToken?.length}');
        debugPrint(
          'AUTH HEADER : '
          '${ApiConfig.headers.containsKey('Authorization')}',
        );
        debugPrint('=================================');
        debugPrint('');

        // ======================================================
        // VALIDATE JWT
        // ======================================================

        if (JwtDecoder.isExpired(token)) {
          ApiConfig.clearToken();

          if (!mounted) return;

          _showSnackBar('Token login sudah kedaluwarsa.', Colors.red);

          return;
        }

        // ======================================================
        // DECODE TOKEN
        // ======================================================

        Map<String, dynamic> decodedToken;

        try {
          decodedToken = JwtDecoder.decode(token);
        } catch (e) {
          ApiConfig.clearToken();

          debugPrint('JWT decode error: $e');

          if (!mounted) return;

          _showSnackBar('Token login tidak valid.', Colors.red);

          return;
        }

        debugPrint('DECODED TOKEN: $decodedToken');

        final String role = (decodedToken['role'] ?? '')
            .toString()
            .toUpperCase()
            .trim();

        debugPrint('USER ROLE: $role');

        // ======================================================
        // REGULAR USER
        // ======================================================

        if (role == 'REGULAR_USER') {
          if (!mounted) return;

          _showSnackBar('Selamat Datang!', Colors.green);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );

          return;
        }

        // ======================================================
        // INVALID ROLE
        // ======================================================

        ApiConfig.clearToken();

        if (!mounted) return;

        _showSnackBar("Role '$role' tidak memiliki akses mobile.", Colors.red);

        return;
      }

      // ========================================================
      // LOGIN FAILED
      // ========================================================

      String errorMessage = 'Login gagal';

      if (responseData is Map) {
        final dynamic message = responseData['message'];

        if (message != null && message.toString().trim().isNotEmpty) {
          errorMessage = message.toString();
        }
      }

      if (!mounted) return;

      _showSnackBar(errorMessage, Colors.red);
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('========== LOGIN ERROR ==========');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('=================================');
      debugPrint('');

      if (!mounted) return;

      _showSnackBar('Tidak dapat terhubung ke server.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // SOCIAL BUTTON
  // ============================================================

  Widget _socialButton({
    required String label,
    IconData? icon,
    String? imagePath,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: Color(0xFFD0D5DD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              Image.asset(
                imagePath,
                height: 20,
                width: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.account_circle, size: 20);
                },
              )
            else
              Icon(icon, color: color, size: 20),

            const SizedBox(width: 8),

            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF344054)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REMEMBER + FORGOT
  // ============================================================

  Widget _buildRememberForgot(double width) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        // ==========================
        // REMEMBER ME (KIRI)
        // ==========================
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,

            children: [
              SizedBox(
                width: 24,

                height: 24,

                child: Checkbox(
                  value: _rememberMe,

                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,

                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                ),
              ),

              const SizedBox(width: 8),

              const Flexible(
                child: Text(
                  'Ingat Saya',

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        // ==========================
        // FORGOT PASSWORD (KANAN)
        // ==========================
        TextButton(
          onPressed: _openForgotPassword,

          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,

            minimumSize: Size.zero,

            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),

          child: const Text(
            'Lupa Password?',

            style: TextStyle(fontSize: 14, color: Color(0xFF2E7D32)),
          ),
        ),
      ],
    );
  }
  // ============================================================
  // SOCIAL LOGIN
  // ============================================================

  Widget _buildSocialLogin(double width) {
    // ==========================================================
    // MOBILE KECIL
    // ==========================================================

    if (width < 360) {
      return Column(
        children: [
          _socialButton(
            label: 'Facebook',
            icon: Icons.facebook,
            color: Colors.blue,
          ),

          const SizedBox(height: 12),

          _socialButton(
            label: 'Google',
            imagePath: 'assets/google.png',
            color: Colors.red,
          ),
        ],
      );
    }

    // ==========================================================
    // NORMAL
    // ==========================================================

    return Row(
      children: [
        Expanded(
          child: _socialButton(
            label: 'Facebook',
            icon: Icons.facebook,
            color: Colors.blue,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _socialButton(
            label: 'Google',
            imagePath: 'assets/google.png',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider(double width) {
    if (width < 220) {
      return const Center(
        child: Text(
          'Atau Masuk Dengan',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      );
    }

    return const Row(
      children: [
        Expanded(child: Divider()),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Atau Masuk Dengan',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),

        Expanded(child: Divider()),
      ],
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;
            final bool compactLayout = screenWidth < 360 || screenHeight < 700;

            // ==================================================
            // RESPONSIVE VALUE
            // ==================================================

            final double horizontalPadding = screenWidth < 220
                ? 10
                : screenWidth < 360
                ? 16
                : 24;

            final double logoHeight = screenWidth < 220 || screenHeight < 600
                ? 80
                : screenWidth < 360
                ? 100
                : 150;

            final double topSpacing = screenHeight < 600
                ? 12
                : screenWidth < 360
                ? 24
                : 50;

            final double titleSize = screenWidth < 300 ? 22 : 24;

            // ==================================================
            // CONTENT
            // ==================================================

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),

                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: topSpacing),

                      // =========================================
                      // LOGO
                      // =========================================
                      Center(
                        child: Image.asset(
                          'assets/logo.png',
                          height: logoHeight,
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(height: compactLayout ? 20 : 40),

                      // =========================================
                      // TITLE
                      // =========================================
                      Text(
                        'Masuk',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D2939),
                        ),
                      ),

                      SizedBox(height: compactLayout ? 16 : 24),

                      // =========================================
                      // EMAIL
                      // =========================================
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF344054),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'nama@email.com',

                          prefixIcon: screenWidth < 220
                              ? null
                              : const Icon(Icons.email_outlined),

                          isDense: true,

                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                      SizedBox(height: compactLayout ? 14 : 20),

                      // =========================================
                      // PASSWORD
                      // =========================================
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF344054),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _passwordController,

                        obscureText: _obscureText,

                        textInputAction: TextInputAction.done,

                        onSubmitted: (_) {
                          if (!_isLoading) {
                            _handleLogin();
                          }
                        },

                        decoration: InputDecoration(
                          hintText: '************',

                          isDense: true,

                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),

                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                      SizedBox(height: compactLayout ? 6 : 10),

                      // =========================================
                      // REMEMBER / FORGOT
                      // =========================================
                      _buildRememberForgot(screenWidth),

                      SizedBox(height: compactLayout ? 14 : 22),

                      // =========================================
                      // LOGIN
                      // =========================================
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
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: compactLayout ? 20 : 30),

                      // =========================================
                      // DIVIDER
                      // =========================================
                      _buildDivider(screenWidth),

                      SizedBox(height: compactLayout ? 16 : 24),

                      // =========================================
                      // SOCIAL
                      // =========================================
                      _buildSocialLogin(screenWidth),

                      SizedBox(height: compactLayout ? 24 : 38),

                      // =========================================
                      // REGISTER
                      // =========================================
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          children: [
                            const Text("Don't have an account?"),

                            GestureDetector(
                              onTap: _openRegister,
                              child: const Text(
                                'Daftar Sekarang',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // =========================================
                      // BANNER
                      // =========================================
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),

                        child: Image.asset(
                          'assets/br.jpeg',
                          width: double.infinity,
                          fit: BoxFit.cover,

                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // =========================================
                      // FOOTER
                      // =========================================
                      const Center(
                        child: Column(
                          children: [
                            Text(
                              '© 2026 EcoCash Indonesia',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              'v1.0.0',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
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
          },
        ),
      ),
    );
  }
}
