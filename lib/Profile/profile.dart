import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/profile/editprofile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'daftar_alamat_page.dart';

// Alias tipe agar tidak terpotong saat proses salin
typedef ProfileMap = Map<String, dynamic>;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  late Future<ProfileMap> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = fetchUserProfile();
  }

  Future<ProfileMap> fetchUserProfile() async {
    final response = await http.get(
      Uri.parse(ApiConfig.getUserProfile),
      headers: ApiConfig.headers,
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final dynamic data = jsonResponse['data'] ?? jsonResponse;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } else {
      throw Exception('Gagal memuat profil: ${response.statusCode}');
    }
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = fetchUserProfile();
    });
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun EcoCash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ApiConfig.userToken = null;
              Navigator.pop(context);
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: FutureBuilder<ProfileMap>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryNavy));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark),
                    onPressed: _refreshProfile,
                    child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          final user = snapshot.data ?? {};

          return RefreshIndicator(
            onRefresh: () async => _refreshProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(context),
                  Transform.translate(
                    offset: const Offset(0, -50),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _buildProfileCard(context, user),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFEA2E),
            brandYellow,
            Color(0xFFFFDF00),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 21),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Profil Saya',
                  style: TextStyle(color: textDark, fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, ProfileMap user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          _buildProfileIdentity(user),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          _buildMenuTile(
            icon: Icons.edit_note_rounded,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            title: 'Edit Profil Akun',
            subtitle: 'Nama lengkap & kontak email',
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfilePage(user: user)),
              );
              if (updated == true) {
                _refreshProfile();
              }
            },
          ),
          _buildMenuTile(
            icon: Icons.location_on_rounded,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            title: 'Daftar Alamat Rumah',
            subtitle: 'Alamat jemput sampah & koordinat PostGIS',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DaftarAlamatPage(isSelecting: false)),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.security_rounded,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: 'Keamanan Akun & PIN',
            subtitle: 'Proteksi dompet & kata sandi',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur keamanan & ubah PIN segera hadir.')),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.notifications_active_rounded,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF9333EA),
            title: 'Notifikasi Penjemputan',
            subtitle: 'Info status pesanan & saldo masuk',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifikasi dalam aplikasi aktif.')),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildProfileIdentity(ProfileMap user) {
    final String initial = ((user['name'] ?? 'W').toString().isNotEmpty)
        ? (user['name'] ?? 'W').toString()[0].toUpperCase()
        : 'W';

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: const Color(0xFFD4A000).withOpacity(0.2), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: brandYellow.withOpacity(0.35),
                child: Text(
                  initial,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: primaryNavy),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Color(0xFF00AA13), shape: BoxShape.circle),
              child: const Icon(Icons.verified, color: Colors.white, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          user['name'] ?? 'Nama Pengguna',
          textAlign: TextAlign.center,
          style: const TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          user['email'] ?? 'email@example.com',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Keluar dari Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}