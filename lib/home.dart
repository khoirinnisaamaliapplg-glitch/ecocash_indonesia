import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:ecocash_indonesia/bantuan/bantuan.dart';
import 'package:ecocash_indonesia/ecomer/ecomer.dart';
import 'package:ecocash_indonesia/history/refund.dart';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/maps/maps.dart';
import 'package:ecocash_indonesia/profile/profile.dart';
import 'package:ecocash_indonesia/saldo/saldo.dart';
import 'package:ecocash_indonesia/setor_sampah/scan.dart';
import 'package:ecocash_indonesia/tf/transfer.dart';
import 'package:ecocash_indonesia/voucher/voucher.dart';
import 'package:ecocash_indonesia/pickupwaste/pickup_waste.dart';

// Alias tipe data agar kebal error copy-paste
typedef UserDataMap = Map<String, dynamic>;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Palet Warna Identitas EcoCash x Gojek Theme
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color brandYellowDark = Color(0xFFF5D000);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color gopayBlue = Color(0xFF0081A7);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  late Future<UserDataMap> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  // ============================================================
  // FETCH PROFILE + WALLET + CARBON (LOGIKA BE UTUH 100%)
  // ============================================================

  Future<UserDataMap> _fetchUserData() async {
    final List<http.Response> responses = await Future.wait([
      http.get(Uri.parse(ApiConfig.getUserProfile), headers: ApiConfig.headers),
      http.get(Uri.parse(ApiConfig.getMyWallet), headers: ApiConfig.headers),
      http.get(Uri.parse(ApiConfig.getMyCarbon), headers: ApiConfig.headers),
    ]);

    final http.Response profileResponse = responses[0];
    final http.Response walletResponse = responses[1];
    final http.Response carbonResponse = responses[2];

    if (profileResponse.statusCode != 200) {
      throw Exception('Gagal memuat profil: ${profileResponse.statusCode}');
    }
    if (walletResponse.statusCode != 200) {
      throw Exception('Gagal memuat dompet: ${walletResponse.statusCode}');
    }
    if (carbonResponse.statusCode != 200) {
      throw Exception('Gagal memuat carbon: ${carbonResponse.statusCode}');
    }

    final dynamic decodedProfile = jsonDecode(profileResponse.body);
    final dynamic decodedWallet = jsonDecode(walletResponse.body);
    final dynamic decodedCarbon = jsonDecode(carbonResponse.body);

    final UserDataMap profileData = _extractDataMap(decodedProfile);
    final UserDataMap walletData = _extractDataMap(decodedWallet);
    final UserDataMap carbonData = _extractDataMap(decodedCarbon);

    return {
      ...walletData,
      ...profileData,
      'carbon': carbonData['totalSavedKg'] ?? 0,
      'carbonUnit': carbonData['unit'] ?? 'kg CO2e',
      'carbonChange': carbonData['changePercent'] ?? 0,
      'totalWasteKg': carbonData['totalWasteKg'] ?? 0,
      'carbonTransactions': carbonData['transactions'] ?? 0,
      'carbonTrend': carbonData['trend'] ?? [],
    };
  }

  UserDataMap _extractDataMap(dynamic responseData) {
    if (responseData is! Map) return {};
    final Map<String, dynamic> responseMap = Map<String, dynamic>.from(responseData);
    final dynamic data = responseMap['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return responseMap;
  }

  Future<void> _refreshData() async {
    final Future<UserDataMap> newFuture = _fetchUserData();
    setState(() {
      _userDataFuture = newFuture;
    });
    await newFuture;
  }

  String _getUserName(UserDataMap data) {
    final String name = data['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final String username = data['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) return username;
    return 'Warga EcoCash';
  }

  String _formatCarbon(dynamic value) {
    if (value == null) return '0';
    final double number = double.tryParse(value.toString()) ?? 0;
    if (number == number.truncateToDouble()) return number.toInt().toString();
    return number.toStringAsFixed(2);
  }

  String _formatBalance(dynamic value) {
    if (value == null) return '0';
    final double number = double.tryParse(value.toString()) ?? 0;
    return number.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.',
    );
  }

  Future<void> _openPartnerApp() async {
    const String partnerUrl = "ecocashpartner://open";
    final Uri url = Uri.parse(partnerUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final Uri storeUrl = Uri.parse("http://partner.ecocash.id/");
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: textDark,
        backgroundColor: brandYellow,
        child: FutureBuilder<UserDataMap>(
          future: _userDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: brandYellowDark));
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 55, color: Colors.redAccent),
                          const SizedBox(height: 15),
                          Text('Gagal memuat data: ${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandYellow,
                              foregroundColor: textDark,
                              elevation: 0,
                            ),
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final UserDataMap data = snapshot.data ?? {};

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildGojekStyleHeader(context, data),
                  const SizedBox(height: 16),
                  _buildGojekServiceGrid(context),
                  const SizedBox(height: 16),
                  _buildEcoCashPlusBanner(context),
                  const SizedBox(height: 20),
                  _buildNearestContainerShortcut(context),
                  const SizedBox(height: 20),
                  _buildPromoCarouselSection(context),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // 1. HEADER KUNING GOJEK (Search Bar + Banner Presisi + Wallet)
  // ============================================================

  Widget _buildGojekStyleHeader(BuildContext context, UserDataMap data) {
    final String username = _getUserName(data);

    return Container(
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              // Search Bar + Member Pill + Profile Avatar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: Colors.grey, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cari kontainer, jenis botol, promo...',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 18),
                        SizedBox(width: 4),
                        Text('Member', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfilePage()),
                      ).then((_) => _refreshData());
                    },
                    child: CircleAvatar(
                      radius: 21,
                      backgroundColor: textDark,
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: Colors.white,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Hero Banner Ilustrasi Lengkap (Gedung Sate, Kurir, Smart Container, Pasupati)
              _buildHeroIllustrationBanner(context, username),

              const SizedBox(height: 14),

              // Compact Gojek/GoPay-style Wallet Card
              _buildGojekWalletCard(context, data),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HERO BANNER UTUH TANPA TERPOTONG
  // ============================================================

  Widget _buildHeroIllustrationBanner(BuildContext context, String username) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PickupWastePage()),
        );
      },
      child: Container(
        width: double.infinity,
        height: 135,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Menghitung lebar ilustrasi agar Gedung Sate tidak terpotong
              final double illustrationWidth = constraints.maxWidth > 380
                  ? 285.0
                  : (constraints.maxWidth * 0.74).clamp(230.0, 285.0);

              return Stack(
                children: [
                  // 1. Gambar Ilustrasi Lengkap di Sisi Kanan (Gedung Sate, Balon Dialog, Kurir, Mesin, Jembatan)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: illustrationWidth,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/Banner_Apps_Home_1-02.png',
                            fit: BoxFit.fitHeight,
                            alignment: Alignment.centerRight,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/banner_home.jpg',
                              fit: BoxFit.fitHeight,
                              alignment: Alignment.centerRight,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/background.png',
                                fit: BoxFit.fitHeight,
                                alignment: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                        // Gradasi halus di tepi kiri gambar agar menyatu mulus dengan kartu putih tanpa garis hitam
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Konten Teks di Sisi Kiri
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: brandYellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.eco_rounded, color: textDark, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'EcoHero',
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hi, $username! 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Less waste, more impact!',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F2C59),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: textDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Setor Sampah',
                                style: TextStyle(color: brandYellow, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, color: brandYellow, size: 9),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 2. KARTU SALDO COMPACT (Gojek Pay Style)
  // ============================================================

  Widget _buildGojekWalletCard(BuildContext context, UserDataMap data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gopayBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet, color: gopayBlue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rp${_formatBalance(data['balance'])}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.eco, size: 12, color: ecoGreen),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCarbon(data['carbon'])} kg terhemat',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ecoGreen),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Text(
                          '${data['points'] ?? '0'} poin',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEAB308)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildGojekActionBtn(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Pindai',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScanPage()),
                      ).then((_) => _refreshData());
                    },
                  ),
                  const SizedBox(width: 14),
                  _buildGojekActionBtn(
                    icon: Icons.add_circle,
                    label: 'Isi Saldo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const IsiSaldoPage()),
                      ).then((_) => _refreshData());
                    },
                  ),
                  const SizedBox(width: 14),
                  _buildGojekActionBtn(
                    icon: Icons.history_rounded,
                    label: 'Riwayat',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RefundsScreen()),
                      ).then((_) => _refreshData());
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGojekActionBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: gopayBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textDark)),
        ],
      ),
    );
  }

  // ============================================================
  // 3. ICON GRID 4x2 KHAS GOJEK (Layanan Utama & Badge)
  // ============================================================

  Widget _buildGojekServiceGrid(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGridItem(
                context,
                title: 'EcoJemput',
                icon: Icons.local_shipping_rounded,
                bgColor: const Color(0xFFDCFCE7),
                iconColor: ecoGreen,
                badgeText: 'Driver',
                badgeColor: const Color(0xFFDC2626),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PickupWastePage()),
                  ).then((_) => _refreshData());
                },
              ),
              _buildGridItem(
                context,
                title: 'EcoDrop',
                icon: Icons.inventory_2_rounded,
                bgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                badgeText: '24 Jam',
                badgeColor: ecoGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Maps()),
                  ).then((_) => _refreshData());
                },
              ),
              _buildGridItem(
                context,
                title: 'EcoMart',
                icon: Icons.storefront_rounded,
                bgColor: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                badgeText: 'Diskon',
                badgeColor: const Color(0xFFDC2626),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EcomerPage()),
                  ).then((_) => _refreshData());
                },
              ),
              _buildGridItem(
                context,
                title: 'EcoDonasi',
                icon: Icons.volunteer_activism_rounded,
                bgColor: const Color(0xFFFCE7F3),
                iconColor: const Color(0xFFDB2777),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DonationPage()),
                  ).then((_) => _refreshData());
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGridItem(
                context,
                title: 'Voucher',
                icon: Icons.confirmation_number_rounded,
                bgColor: const Color(0xFFFFFBEB),
                iconColor: const Color(0xFFB45309),
                badgeText: 'Klaim',
                badgeColor: const Color(0xFFEAB308),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VoucherPage()),
                  );
                },
              ),
              _buildGridItem(
                context,
                title: 'Transfer',
                icon: Icons.swap_horiz_rounded,
                bgColor: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TransferPage()),
                  ).then((_) => _refreshData());
                },
              ),
              _buildGridItem(
                context,
                title: 'Mitra Kurir',
                icon: Icons.business_center_rounded,
                bgColor: const Color(0xFFE2E8F0),
                iconColor: const Color(0xFF475569),
                badgeText: 'Kerja',
                badgeColor: const Color(0xFF2563EB),
                onTap: () {
                  _openPartnerApp();
                },
              ),
              _buildGridItem(
                context,
                title: 'Lainnya',
                icon: Icons.apps_rounded,
                bgColor: const Color(0xFFF1F5F9),
                iconColor: textDark,
                onTap: () => _showAllFeaturesModal(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    String? badgeText,
    Color badgeColor = Colors.red,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                if (badgeText != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 4. STRIP BANNER ECOCASH PLUS (Gojek Discover PLUS Style)
  // ============================================================

  Widget _buildEcoCashPlusBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC7F9CC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF80ED99)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: ecoGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Gratis Biaya Penjemputan Sampah!',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                ),
                Text(
                  'Kumpulkan min. 20 kg sampah daur ulang per order',
                  style: TextStyle(fontSize: 10, color: Color(0xFF1E3A2F)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PickupWastePage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ecoGreen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Jemput ->', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 5. PINTASAN KONTROL TITIK TERDEKAT
  // ============================================================

  Widget _buildNearestContainerShortcut(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Titik Setor Rekomendasi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: brandYellow.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: textDark, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Smart Container Stasiun Bandung',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '📍 Radius 1.4 Km • Stasiun Hall Bandung',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Maps()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: textDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Buka Rute', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 6. PROMO CAROUSEL CARD
  // ============================================================

  Widget _buildPromoCarouselSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: brandYellow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PROMO MINGGU INI',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tukar 50 Botol PET,\nDapat Bonus 5.000 Poin',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Berlaku di seluruh Smart Container Bandung',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VoucherPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: textDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                elevation: 0,
              ),
              child: const Text('Detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllFeaturesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Semua Layanan EcoCash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: primaryNavy),
                title: const Text('Profil Pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Pengaturan akun & alamat rumah'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_center_rounded, color: ecoGreen),
                title: const Text('Pusat Bantuan & Edukasi', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Panduan pemilahan jenis sampah'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DonationPage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}