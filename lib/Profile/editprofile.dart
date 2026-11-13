import 'dart:convert';
import 'dart:typed_data';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

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
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _currentAvatarUrl;

  bool _isLoading = false;
  bool _isSendingVerify = false;

  bool get _isEmailVerified =>
      widget.user['isVerified'] == true ||
      widget.user['isEmailVerified'] == true ||
      widget.user['emailVerifiedAt'] != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.user['name'] ?? '').toString();
    _usernameController.text = (widget.user['username'] ?? '').toString();
    _emailController.text = (widget.user['email'] ?? '').toString();
    final rawAvatar = (widget.user['avatarUrl'] ?? '').toString().trim();
    if (rawAvatar.isNotEmpty && rawAvatar != 'null') {
      _currentAvatarUrl = rawAvatar;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showPickImageSheet() {
    if (_isLoading) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubah Foto Profil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFFD97706)),
                ),
                title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Format JPG, PNG, WEBP (Maks. 5MB)', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text('Ambil Foto Kamera', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = picked.name.isNotEmpty ? picked.name : 'profile.jpg';
      });
    } catch (_) {
      _showSnackBar('Tidak dapat mengakses gambar', isError: true);
    }
  }

  /// Deteksi MIME type asli dari header byte file agar tidak terkirim sebagai application/octet-stream
  MediaType _detectImageMediaType(Uint8List bytes, String? fileName) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return MediaType('image', 'jpeg');
    }

    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  Future<String?> _uploadAvatarImage() async {
    if (_selectedImageBytes == null) return _currentAvatarUrl;

    final mediaType = _detectImageMediaType(_selectedImageBytes!, _selectedImageName);
    final ext = mediaType.subtype == 'jpeg' ? 'jpg' : mediaType.subtype;

    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.uploadSingle));
    if (ApiConfig.hasToken) {
      request.headers['Authorization'] = 'Bearer ${ApiConfig.userToken!.trim()}';
    }
    // Wajib mengirim field 'category' SEBELUM 'file' sesuai aturan middleware upload backend
    request.fields['category'] = 'profile';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        _selectedImageBytes!,
        filename: 'profile.$ext',
        contentType: mediaType,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final String? url = (decoded['data']?['url'] ?? decoded['url'])?.toString();
      if (url != null && url.isNotEmpty) return url;
    }

    final String msg = decoded is Map && decoded['message'] != null
        ? decoded['message'].toString()
        : 'Gagal mengunggah foto profil (${response.statusCode})';
    throw Exception(msg);
  }

  Future<void> _updateProfile() async {
    final String name = _nameController.text.trim();
    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim().toLowerCase();
    final String originalEmail = (widget.user['email'] ?? '').toString().trim().toLowerCase();

    if (name.length < 2) {
      _showSnackBar('Nama lengkap minimal 2 karakter', isError: true);
      return;
    }

    if (username.isNotEmpty && !RegExp(r'^[a-zA-Z0-9_]{3,50}$').hasMatch(username)) {
      _showSnackBar('Username hanya boleh huruf, angka, atau garis bawah (3-50 karakter)', isError: true);
      return;
    }

    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('Format alamat email tidak valid', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String? uploadedAvatarUrl = await _uploadAvatarImage();

      final Map<String, dynamic> profileBody = {'name': name};
      if (username.isNotEmpty) {
        profileBody['username'] = username;
      }
      if (uploadedAvatarUrl != null && uploadedAvatarUrl.isNotEmpty) {
        profileBody['avatarUrl'] = uploadedAvatarUrl;
      }

      final response = await http.patch(
        Uri.parse(ApiConfig.updateProfile),
        headers: ApiConfig.headers,
        body: jsonEncode(profileBody),
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode != 200 && response.statusCode != 201) {
        final String errorMsg = decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Gagal memperbarui profil (${response.statusCode})';
        throw Exception(errorMsg);
      }

      if (email != originalEmail && !_isEmailVerified) {
        final emailRes = await http.patch(
          Uri.parse(ApiConfig.changeEmail),
          headers: ApiConfig.headers,
          body: jsonEncode({'email': email}),
        );
        if (emailRes.statusCode != 200) {
          dynamic emailErr;
          try {
            emailErr = jsonDecode(emailRes.body);
          } catch (_) {}
          throw Exception(
            emailErr is Map && emailErr['message'] != null
                ? emailErr['message'].toString()
                : 'Gagal memperbarui alamat email',
          );
        }
      }

      if (!mounted) return;
      _showSnackBar('Profil berhasil diperbarui');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendEmailVerification() async {
    setState(() => _isSendingVerify = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.sendEmailVerification),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _showSnackBar('Tautan verifikasi email telah dikirim ulang');
      } else {
        _showSnackBar('Gagal mengirim tautan verifikasi', isError: true);
      }
    } catch (_) {
      _showSnackBar('Terjadi kesalahan jaringan', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingVerify = false);
    }
  }

  void _showVerifiedEmailInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Email Sudah Terverifikasi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        content: const Text(
          'Alamat email yang sudah terverifikasi terkunci untuk keamanan akun (OTP & reset PIN). Jika perlu mengganti email terdaftar, silakan hubungi Pusat Bantuan.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark, elevation: 0),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : ecoGreen,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final String phone = (widget.user['phoneNumber'] ?? '-').toString();

    return Scaffold(
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileAvatar(),
                    const SizedBox(height: 22),
                    const Text(
                      'Informasi Pribadi',
                      style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Perbarui foto profil, nama lengkap, dan username Anda.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    _buildInputLabel('Nama Lengkap'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Masukkan nama lengkap',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel('Username'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _usernameController,
                      hintText: 'Contoh: dwi_junior',
                      icon: Icons.alternate_email_rounded,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInputLabel('Email'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isEmailVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _isEmailVerified ? 'Terverifikasi' : 'Belum Verifikasi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isEmailVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Masukkan alamat email',
                      icon: Icons.email_outlined,
                      readOnly: _isEmailVerified,
                      suffixIcon: _isEmailVerified
                          ? const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey)
                          : null,
                      onTap: _isEmailVerified ? _showVerifiedEmailInfoDialog : null,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (!_isEmailVerified) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _isSendingVerify ? null : _resendEmailVerification,
                          icon: const Icon(Icons.mark_email_unread_outlined, size: 16),
                          label: Text(
                            _isSendingVerify ? 'Mengirim...' : 'Kirim Ulang Link Verifikasi',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                    if (phone.isNotEmpty && phone != '-' && phone != 'null') ...[
                      const SizedBox(height: 12),
                      _buildInputLabel('Nomor Telepon Terdaftar'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_android_rounded, size: 18, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text(phone, style: const TextStyle(fontWeight: FontWeight.w600, color: textDark)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    _buildSaveButton(),
                  ],
                ),
              ),
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

  Widget _buildProfileAvatar() {
    final String initial = (_nameController.text.trim().isNotEmpty)
        ? _nameController.text.trim()[0].toUpperCase()
        : 'W';

    ImageProvider? avatarImage;
    if (_selectedImageBytes != null) {
      avatarImage = MemoryImage(_selectedImageBytes!);
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_currentAvatarUrl!);
    }

    return Center(
      child: GestureDetector(
        onTap: _showPickImageSheet,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFFD4A000).withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: brandYellow.withValues(alpha: 0.35),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        initial,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: primaryNavy),
                      )
                    : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: textDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: brandYellow, size: 15),
            ),
          ],
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
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: TextStyle(
        color: readOnly ? Colors.grey.shade700 : textDark,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: readOnly ? Colors.grey.shade300 : textDark, width: 1.5),
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
