import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/Profile/editprofile.dart';
import 'package:ecocash_indonesia/Profile/keamanan_pin_page.dart';
import 'package:ecocash_indonesia/Profile/notifikasi_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'daftar_alamat_page.dart';

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
  int _unreadNotifCount = 0;

  @override
  void initState() {
    super.initState();
    _profileFuture = fetchUserProfile();
    _fetchUnreadCount();
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

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.getNotifications}?limit=1'),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body);
        final count = int.tryParse((body['data']?['unreadCount'] ?? 0).toString()) ?? 0;
        setState(() => _unreadNotifCount = count);
      }
    } catch (_) {}
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = fetchUserProfile();
    });
    _fetchUnreadCount();
  }

  Future<void> _performLogout(BuildContext context) async {
    try {
      if (ApiConfig.hasToken) {
        await http.post(
          Uri.parse(ApiConfig.logout),
          headers: ApiConfig.headers,
        );
      }
    } catch (_) {
    } finally {
      ApiConfig.clearToken();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
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
              _performLogout(context);
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
    final bool isEmailVerified =
        user['isVerified'] == true || user['isEmailVerified'] == true || user['emailVerifiedAt'] != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          _buildProfileIdentity(user, isEmailVerified),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          _buildMenuTile(
            icon: Icons.edit_note_rounded,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            title: 'Edit Profil Akun',
            subtitle: 'Foto profil, nama lengkap & username',
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
            subtitle: 'Kelola PIN transaksi 6-digit & kata sandi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => KeamananPinPage(
                    userEmail: (user['email'] ?? '').toString(),
                    isEmailVerified: isEmailVerified,
                  ),
                ),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.notifications_active_rounded,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF9333EA),
            title: 'Notifikasi',
            subtitle: 'Info penjemputan, setor mesin & saldo masuk',
            badgeCount: _unreadNotifCount,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotifikasiPage()),
              );
              _fetchUnreadCount();
            },
          ),
          const SizedBox(height: 20),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildProfileIdentity(ProfileMap user, bool isEmailVerified) {
    final String name = (user['name'] ?? 'Nama Pengguna').toString();
    final String username = (user['username'] ?? '').toString();
    final String email = (user['email'] ?? 'email@example.com').toString();
    final String avatarUrl = (user['avatarUrl'] ?? '').toString().trim();
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';
    final bool hasAvatar = avatarUrl.isNotEmpty && avatarUrl != 'null';

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
                  BoxShadow(color: const Color(0xFFD4A000).withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: brandYellow.withValues(alpha: 0.35),
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                child: !hasAvatar
                    ? Text(
                        initial,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: primaryNavy),
                      )
                    : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isEmailVerified ? const Color(0xFF00AA13) : Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEmailVerified ? Icons.verified : Icons.priority_high_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (username.isNotEmpty && username != 'null') ...[
          const SizedBox(height: 2),
          Text(
            '@$username',
            style: const TextStyle(color: primaryNavy, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          email,
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
    int badgeCount = 0,
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
                if (badgeCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
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
