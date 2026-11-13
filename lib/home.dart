import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:ecocash_indonesia/bantuan/bantuan.dart';
import 'package:ecocash_indonesia/ecomer/ecomer.dart';
import 'package:ecocash_indonesia/history/refund.dart';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/maps/maps.dart';
import 'package:ecocash_indonesia/poin/ecopoints_page.dart';
import 'package:ecocash_indonesia/profile/profile.dart';
import 'package:ecocash_indonesia/saldo/saldo.dart';
import 'package:ecocash_indonesia/setor_sampah/scan.dart';
import 'package:ecocash_indonesia/tf/transfer.dart';
import 'package:ecocash_indonesia/voucher/voucher.dart';
import 'package:ecocash_indonesia/pickupwaste/pickup_waste.dart';
import 'package:ecocash_indonesia/pusat_bantuan/pusat_bantuan_page.dart';

typedef UserDataMap = Map<String, dynamic>;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color brandYellowDark = Color(0xFFF5D000);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color gopayBlue = Color(0xFF0081A7);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  late Future<UserDataMap> _userDataFuture;

  final PageController _promoPageController = PageController();
  Timer? _promoAutoSlideTimer;
  int _currentPromoIndex = 0;
  int _promoCount = 1;

  static const List<UserDataMap> _defaultPromos = [
    {
      'badgeText': 'PROMO MINGGU INI',
      'title': 'Tukar 50 Botol PET,\nDapat Bonus 5.000 Poin',
      'subtitle': 'Berlaku di seluruh Smart Container EcoCash',
      'description': 'Setorkan botol plastik PET melalui Smart Container QR terdekat dan kumpulkan EcoPoints yang dapat ditukar menjadi saldo dompet atau donasi.',
      'bgColorHex': '#1E293B',
      'actionType': 'ECOPOINTS',
    },
  ];

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
    _startPromoAutoSlide();
  }

  @override
  void dispose() {
    _promoAutoSlideTimer?.cancel();
    _promoPageController.dispose();
    super.dispose();
  }

  void _startPromoAutoSlide() {
    _promoAutoSlideTimer?.cancel();
    _promoAutoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _promoCount <= 1 || !_promoPageController.hasClients) return;
      final nextIndex = (_currentPromoIndex + 1) % _promoCount;
      _promoPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<UserDataMap> _fetchUserData() async {
    final List<http.Response> responses = await Future.wait([
      http.get(Uri.parse(ApiConfig.getUserProfile), headers: ApiConfig.headers),
      http.get(Uri.parse(ApiConfig.getMyWallet), headers: ApiConfig.headers),
      http.get(Uri.parse(ApiConfig.getMyCarbon), headers: ApiConfig.headers),
      http.get(Uri.parse(ApiConfig.getPublicPromoBanners), headers: ApiConfig.headers).catchError(
            (_) => http.Response('{"success":false,"data":[]}', 500),
          ),
    ]);

    final http.Response profileResponse = responses[0];
    final http.Response walletResponse = responses[1];
    final http.Response carbonResponse = responses[2];
    final http.Response promoResponse = responses[3];

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

    List<UserDataMap> promoBanners = List<UserDataMap>.from(_defaultPromos);
    if (promoResponse.statusCode == 200) {
      try {
        final decodedPromo = jsonDecode(promoResponse.body);
        final rawList = decodedPromo is Map ? decodedPromo['data'] : null;
        if (rawList is List && rawList.isNotEmpty) {
          promoBanners = rawList
              .whereType()
              .map((item) => Map<String, dynamic>.from(item))
              .take(3)
              .toList();
        }
      } catch (_) {}
    }

    _promoCount = promoBanners.length;
    if (_currentPromoIndex >= _promoCount) {
      _currentPromoIndex = 0;
    }

    return {
      ...walletData,
      ...profileData,
      'points': walletData['points'] ?? 0,
      'lifetimePoints': walletData['lifetimePoints'] ?? 0,
      'tier': walletData['tier'] ?? 'EcoStarter',
      'carbon': carbonData['totalSavedKg'] ?? 0,
      'carbonUnit': carbonData['unit'] ?? 'kg CO2e',
      'carbonChange': carbonData['changePercent'] ?? 0,
      'totalWasteKg': carbonData['totalWasteKg'] ?? 0,
      'carbonTransactions': carbonData['transactions'] ?? 0,
      'carbonTrend': carbonData['trend'] ?? [],
      'promoBanners': promoBanners,
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

  Color _parseHexColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.trim().isEmpty) return fallback;
    final clean = hexString.trim().replaceFirst('#', '');
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (clean.length == 8) {
      final parsed = int.tryParse(clean, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  Future<void> _handlePromoAction(BuildContext context, Map<String, dynamic> promo) async {
    final String actionType = (promo['actionType'] ?? 'NONE').toString().toUpperCase();
    final String actionTarget = (promo['actionTarget'] ?? '').toString().trim();

    switch (actionType) {
      case 'ECOPOINTS':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EcoPointsPage()),
        );
        _refreshData();
        break;
      case 'VOUCHER':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VoucherPage()),
        );
        break;
      case 'PICKUP':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PickupWastePage()),
        );
        _refreshData();
        break;
      case 'SCAN':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScanPage()),
        );
        _refreshData();
        break;
      case 'ECOMART':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EcomerPage()),
        );
        _refreshData();
        break;
      case 'DONATION':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DonationPage()),
        );
        _refreshData();
        break;
      case 'EXTERNAL_URL':
        if (actionTarget.isNotEmpty) {
          final uri = Uri.tryParse(actionTarget);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        _showPromoDetailSheet(context, promo);
        break;
      default:
        _showPromoDetailSheet(context, promo);
    }
  }

  void _showPromoDetailSheet(BuildContext context, Map<String, dynamic> promo) {
    final String badge = (promo['badgeText'] ?? 'PROMO ECOCASH').toString();
    final String title = (promo['title'] ?? '').toString().replaceAll('\n', ' ');
    final String subtitle = (promo['subtitle'] ?? '').toString();
    final String description = (promo['description'] ?? '').toString();
    final String imageUrl = (promo['imageUrl'] ?? '').toString().trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
              if (imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textDark),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
              ],
              if (description.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: textDark, height: 1.45),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandYellow,
                    foregroundColor: textDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
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
            final List<UserDataMap> promoBanners =
                (data['promoBanners'] as List<UserDataMap>?) ?? _defaultPromos;

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
                  _buildPromoCarouselSection(context, promoBanners),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGojekStyleHeader(BuildContext context, UserDataMap data) {
    final String username = _getUserName(data);
    final String memberTier = data['tier']?.toString() ?? 'EcoStarter';

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
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openHomeSearchSheet(context, data),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
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
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EcoPointsPage()),
                      ).then((_) => _refreshData());
                    },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            memberTier,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark),
                          ),
                        ],
                      ),
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
                    child: Builder(
                      builder: (context) {
                        final String avatarUrl = (data['avatarUrl'] ?? '').toString().trim();
                        final bool hasAvatar = avatarUrl.isNotEmpty && avatarUrl != 'null';
                        return CircleAvatar(
                          radius: 21,
                          backgroundColor: textDark,
                          child: CircleAvatar(
                            radius: 19,
                            backgroundColor: Colors.white,
                            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                            child: !hasAvatar
                                ? Text(
                                    username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 16),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildHeroIllustrationBanner(context, username),
              const SizedBox(height: 14),
              _buildGojekWalletCard(context, data),
            ],
          ),
        ),
      ),
    );
  }

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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double illustrationWidth = constraints.maxWidth > 380
                  ? 285.0
                  : (constraints.maxWidth * 0.74).clamp(230.0, 285.0);

              return Stack(
                children: [
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
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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

  Widget _buildGojekWalletCard(BuildContext context, UserDataMap data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                  color: gopayBlue.withValues(alpha: 0.12),
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
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EcoPointsPage()),
                            ).then((_) => _refreshData());
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_formatBalance(data['points'] ?? 0)} poin',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 14, color: Color(0xFFD97706)),
                            ],
                          ),
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

  Widget _buildGojekServiceGrid(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: brandYellow.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: textDark, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

  Widget _buildPromoCarouselSection(BuildContext context, List<UserDataMap> promos) {
    final items = promos.isEmpty ? _defaultPromos : promos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Promo & Info Menarik',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
              ),
              if (items.length > 1)
                Text(
                  '${_currentPromoIndex + 1}/${items.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 136,
          child: PageView.builder(
            controller: _promoPageController,
            itemCount: items.length,
            onPageChanged: (index) {
              setState(() => _currentPromoIndex = index);
            },
            itemBuilder: (context, index) {
              final promo = items[index];
              final String badgeText = (promo['badgeText'] ?? 'PROMO MINGGU INI').toString();
              final String title = (promo['title'] ?? '').toString();
              final String subtitle = (promo['subtitle'] ?? '').toString();
              final String imageUrl = (promo['imageUrl'] ?? '').toString().trim();
              final Color startColor = _parseHexColor(promo['bgColorHex']?.toString(), const Color(0xFF1E293B));
              final Color endColor = Color.lerp(startColor, Colors.black, 0.35) ?? const Color(0xFF0F172A);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _handlePromoAction(context, promo),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [startColor, endColor],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: startColor.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          if (imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.22,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: brandYellow,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          badgeText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: textDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => _handlePromoAction(context, promo),
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
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (idx) {
              final bool active = idx == _currentPromoIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? textDark : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
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
                leading: const Icon(Icons.stars_rounded, color: Color(0xFFD97706)),
                title: const Text('EcoPoints & Keanggotaan', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Cek tier member, riwayat & tukar poin'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EcoPointsPage()),
                  ).then((_) => _refreshData());
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: primaryNavy),
                title: const Text('Profil Pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Pengaturan akun & alamat rumah'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())).then((_) => _refreshData());
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_center_rounded, color: ecoGreen),
                title: const Text('Pusat Bantuan & Edukasi', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('FAQ, panduan pemilahan sampah & tiket pengaduan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PusatBantuanPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHomeSearchSheet(BuildContext context, UserDataMap data) {
    final TextEditingController searchCtrl = TextEditingController();
    String query = '';
    bool isLoadingRefs = true;
    List<UserDataMap> wasteTypes = [];
    List<UserDataMap> machines = [];

    final List<UserDataMap> quickMenus = [
      {'title': 'Setor Sampah (Scan QR)', 'category': 'Layanan', 'icon': Icons.qr_code_scanner_rounded, 'route': 'scan'},
      {'title': 'EcoJemput Sampah Rumah', 'category': 'Layanan', 'icon': Icons.local_shipping_rounded, 'route': 'pickup'},
      {'title': 'EcoDrop & Peta Smart Container', 'category': 'Lokasi', 'icon': Icons.location_on_rounded, 'route': 'map'},
      {'title': 'EcoMart Produk Daur Ulang', 'category': 'Belanja', 'icon': Icons.storefront_rounded, 'route': 'ecomart'},
      {'title': 'Voucher & Tukar Poin', 'category': 'Promo', 'icon': Icons.confirmation_number_rounded, 'route': 'voucher'},
      {'title': 'Pusat Bantuan & Panduan Pemilahan', 'category': 'Edukasi', 'icon': Icons.help_center_rounded, 'route': 'help'},
    ];

    bool startedFetch = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (!startedFetch) {
            startedFetch = true;
            Future.wait([
              http.get(Uri.parse(ApiConfig.getWasteTypes), headers: ApiConfig.headers).catchError((_) => http.Response('{}', 500)),
              http.get(Uri.parse(ApiConfig.getPublicMachines), headers: ApiConfig.headers).catchError((_) => http.Response('{}', 500)),
            ]).then((responses) {
              if (!ctx.mounted) return;
              List<UserDataMap> parsedWaste = [];
              List<UserDataMap> parsedMachines = [];
              try {
                final wBody = jsonDecode(responses[0].body);
                final wRaw = wBody is Map ? (wBody['data'] is List ? wBody['data'] : wBody['data']?['items']) : null;
                if (wRaw is List) {
                  parsedWaste = wRaw.whereType().map((e) => UserDataMap.from(e)).toList();
                }
              } catch (_) {}
              try {
                final mBody = jsonDecode(responses[1].body);
                final mRaw = mBody is Map ? (mBody['data'] is List ? mBody['data'] : mBody['data']?['items']) : null;
                if (mRaw is List) {
                  parsedMachines = mRaw.whereType().map((e) => UserDataMap.from(e)).toList();
                }
              } catch (_) {}

              setModalState(() {
                wasteTypes = parsedWaste;
                machines = parsedMachines;
                isLoadingRefs = false;
              });
            });
          }

          final q = query.trim().toLowerCase();
          final filteredMenus = quickMenus
              .where((m) => q.isEmpty || m['title'].toString().toLowerCase().contains(q) || m['category'].toString().toLowerCase().contains(q))
              .toList();
          final filteredMachines = machines
              .where((m) => q.isEmpty || (m['name'] ?? '').toString().toLowerCase().contains(q) || (m['address'] ?? '').toString().toLowerCase().contains(q))
              .take(5)
              .toList();
          final filteredWastes = wasteTypes
              .where((w) => q.isEmpty || (w['name'] ?? '').toString().toLowerCase().contains(q) || (w['category'] ?? '').toString().toLowerCase().contains(q))
              .take(6)
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) => Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Cari Smart Container, botol PET, voucher...',
                      prefixIcon: const Icon(Icons.search, color: textDark),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setModalState(() => query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      children: [
                        if (filteredMenus.isNotEmpty) ...[
                          const Text('Layanan & Fitur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark)),
                          const SizedBox(height: 8),
                          ...filteredMenus.map((item) => ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                                leading: CircleAvatar(
                                  backgroundColor: brandYellow.withValues(alpha: 0.35),
                                  child: Icon(item['icon'] as IconData, color: textDark, size: 18),
                                ),
                                title: Text(item['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(item['category'].toString(), style: const TextStyle(fontSize: 11)),
                                trailing: const Icon(Icons.north_west_rounded, size: 16, color: Colors.grey),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  final route = item['route'];
                                  if (route == 'scan') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanPage())).then((_) => _refreshData());
                                  } else if (route == 'pickup') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PickupWastePage())).then((_) => _refreshData());
                                  } else if (route == 'map') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const Maps()));
                                  } else if (route == 'ecomart') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EcomerPage()));
                                  } else if (route == 'voucher') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherPage()));
                                  } else if (route == 'help') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PusatBantuanPage()));
                                  }
                                },
                              )),
                          const SizedBox(height: 12),
                        ],
                        if (isLoadingRefs)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: primaryNavy)),
                          )
                        else ...[
                          if (filteredMachines.isNotEmpty) ...[
                            const Text('Smart Container', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark)),
                            const SizedBox(height: 8),
                            ...filteredMachines.map((m) => ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFDCFCE7),
                                    child: Icon(Icons.recycling_rounded, color: ecoGreen, size: 18),
                                  ),
                                  title: Text((m['name'] ?? 'Smart Container').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text((m['address'] ?? '-').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const Maps()));
                                  },
                                )),
                            const SizedBox(height: 12),
                          ],
                          if (filteredWastes.isNotEmpty) ...[
                            const Text('Jenis Sampah & Nilai Tukar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark)),
                            const SizedBox(height: 8),
                            ...filteredWastes.map((w) {
                              final price = w['pricePerKg'] ?? w['userPricePerKg'] ?? 0;
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE0F2FE),
                                  child: Icon(Icons.eco_rounded, color: Color(0xFF0284C7), size: 18),
                                ),
                                title: Text((w['name'] ?? 'Sampah Daur Ulang').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('Estimasi Rp $price / kg', style: const TextStyle(fontSize: 11, color: ecoGreen, fontWeight: FontWeight.w600)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanPage())).then((_) => _refreshData());
                                },
                              );
                            }),
                          ],
                          if (filteredMenus.isEmpty && filteredMachines.isEmpty && filteredWastes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text('Tidak ada hasil yang cocok dengan pencarian Anda.', style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
