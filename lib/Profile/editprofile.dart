import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user['name'] ?? '';
    _emailController.text = widget.user['email'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Nama lengkap tidak boleh kosong', isError: true);
      return;
    }

    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('Format alamat email tidak valid', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.updateProfile),
        headers: {
          ...ApiConfig.headers,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
        }),
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui'),
            backgroundColor: Color(0xFF00AA13),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final String errorMsg = decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Gagal memperbarui profil (${response.statusCode})';
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF00AA13),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
              child: _buildFormCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 21),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Edit Profil',
                  style: TextStyle(color: textDark, fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileAvatar(),
          const SizedBox(height: 24),
          const Text(
            'Informasi Pribadi',
            style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Perbarui nama dan alamat email akun Anda.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _buildInputLabel('Nama Lengkap'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hintText: 'Masukkan nama lengkap',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 18),
          _buildInputLabel('Email'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailController,
            hintText: 'Masukkan alamat email',
            icon: Icons.email_outlined,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) {
              if (!_isLoading) _updateProfile();
            },
          ),
          const SizedBox(height: 28),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final String initial = (_nameController.text.trim().isNotEmpty)
        ? _nameController.text.trim()[0].toUpperCase()
        : 'W';

    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: const Color(0xFFD4A000).withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: CircleAvatar(
          radius: 42,
          backgroundColor: brandYellow.withOpacity(0.35),
          child: Text(
            initial,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30, color: primaryNavy),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputAction textInputAction,
    required TextInputType keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: textDark, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: brandYellow,
          foregroundColor: textDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: textDark, strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Simpan Perubahan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
      ),
    );
  }
}