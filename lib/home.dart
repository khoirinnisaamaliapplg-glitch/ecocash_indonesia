import 'dart:convert';

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
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _userDataFuture;

  @override
  void initState() {
    super.initState();

    _userDataFuture = _fetchUserData();
  }

  // ============================================================
  // FETCH PROFILE + WALLET + CARBON
  // ============================================================

  Future<Map<String, dynamic>> _fetchUserData() async {
    final List<http.Response> responses = await Future.wait<http.Response>([
      // PROFILE
      http.get(Uri.parse(ApiConfig.getUserProfile), headers: ApiConfig.headers),

      // WALLET
      http.get(Uri.parse(ApiConfig.getMyWallet), headers: ApiConfig.headers),

      // CARBON
      http.get(Uri.parse(ApiConfig.getMyCarbon), headers: ApiConfig.headers),
    ]);

    final http.Response profileResponse = responses[0];
    final http.Response walletResponse = responses[1];
    final http.Response carbonResponse = responses[2];

    // ==========================================================
    // CHECK PROFILE
    // ==========================================================

    if (profileResponse.statusCode != 200) {
      throw Exception('Gagal memuat profil: ${profileResponse.statusCode}');
    }

    // ==========================================================
    // CHECK WALLET
    // ==========================================================

    if (walletResponse.statusCode != 200) {
      throw Exception('Gagal memuat dompet: ${walletResponse.statusCode}');
    }

    // ==========================================================
    // CHECK CARBON
    // ==========================================================

    if (carbonResponse.statusCode != 200) {
      throw Exception('Gagal memuat carbon: ${carbonResponse.statusCode}');
    }

    // ==========================================================
    // DECODE JSON
    // ==========================================================

    final dynamic decodedProfile = jsonDecode(profileResponse.body);

    final dynamic decodedWallet = jsonDecode(walletResponse.body);

    final dynamic decodedCarbon = jsonDecode(carbonResponse.body);

    // ==========================================================
    // EXTRACT DATA
    // ==========================================================

    final Map<String, dynamic> profileData = _extractDataMap(decodedProfile);

    final Map<String, dynamic> walletData = _extractDataMap(decodedWallet);

    final Map<String, dynamic> carbonData = _extractDataMap(decodedCarbon);

    // ==========================================================
    // DEBUG
    // ==========================================================

    debugPrint('==============================================');

    debugPrint('PROFILE DATA : $profileData');

    debugPrint('WALLET DATA  : $walletData');

    debugPrint('CARBON DATA  : $carbonData');

    debugPrint('==============================================');

    // ==========================================================
    // MERGE DATA
    // ==========================================================

    return {
      // wallet
      ...walletData,

      // profile
      ...profileData,

      // carbon
      'carbon': carbonData['totalSavedKg'] ?? 0,

      'carbonUnit': carbonData['unit'] ?? 'kg CO2e',

      'carbonChange': carbonData['changePercent'] ?? 0,

      'totalWasteKg': carbonData['totalWasteKg'] ?? 0,

      'carbonTransactions': carbonData['transactions'] ?? 0,

      'carbonTrend': carbonData['trend'] ?? [],
    };
  }

  // ============================================================
  // EXTRACT API DATA
  // ============================================================

  Map<String, dynamic> _extractDataMap(dynamic responseData) {
    if (responseData is! Map) {
      return {};
    }

    final Map<String, dynamic> responseMap = Map<String, dynamic>.from(
      responseData,
    );

    final dynamic data = responseMap['data'];

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return responseMap;
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshData() async {
    final Future<Map<String, dynamic>> newFuture = _fetchUserData();

    setState(() {
      _userDataFuture = newFuture;
    });

    await newFuture;
  }

  // ============================================================
  // GET USER NAME
  // ============================================================

  String _getUserName(Map<String, dynamic> data) {
    final String name = data['name']?.toString().trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    final String username = data['username']?.toString().trim() ?? '';

    if (username.isNotEmpty) {
      return username;
    }

    return 'User';
  }

  // ============================================================
  // FORMAT CARBON
  // ============================================================

  String _formatCarbon(dynamic value) {
    if (value == null) {
      return '0';
    }

    final double number = double.tryParse(value.toString()) ?? 0;

    // Jika bilangan bulat:
    // 10.0 -> 10
    if (number == number.truncateToDouble()) {
      return number.toInt().toString();
    }

    // Maksimal 2 angka desimal
    return number.toStringAsFixed(2);
  }

  // ============================================================
  // FORMAT BALANCE
  // ============================================================

  String _formatBalance(dynamic value) {
    if (value == null) {
      return '0';
    }

    final double number = double.tryParse(value.toString()) ?? 0;

    final int integerValue = number.toInt();

    return integerValue.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.',
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _userDataFuture,
          builder: (context, snapshot) {
            // ==================================================
            // LOADING
            // ==================================================

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // ==================================================
            // ERROR
            // ==================================================

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
                          const Icon(
                            Icons.error_outline,
                            size: 55,
                            color: Colors.red,
                          ),

                          const SizedBox(height: 15),

                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            // ==================================================
            // DATA
            // ==================================================

            final Map<String, dynamic> data = snapshot.data ?? {};

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 450, child: _buildHeader(context, data)),

                  const SizedBox(height: 40),

                  _buildCombinedPaymentMenu(context),

                  const SizedBox(height: 50),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data) {
    final String username = _getUserName(data);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 320,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==============================================
                // USER NAME
                // ==============================================
                Text(
                  'Hi, $username!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Ready to recycle?',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
              ],
            ),
          ),
        ),

        // ======================================================
        // BALANCE CARD
        // ======================================================
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: _buildBalanceCard(context, data),
        ),
      ],
    );
  }

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ====================================================
          // BALANCE
          // ====================================================
          Row(
            children: [
              Image.asset('assets/icons/dompet.png', height: 45, width: 45),

              const SizedBox(width: 15),

              Expanded(
                child: Text(
                  'Rp${_formatBalance(data['balance'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D3E50),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // ====================================================
          // CARBON + POINT
          // ====================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // =================================================
              // CARBON
              // =================================================
              Expanded(
                child: _buildStatItem(
                  'Carbon Saved:',
                  '${_formatCarbon(data['carbon'])} kg CO₂e',
                  'assets/icons/daun.png',
                ),
              ),

              const SizedBox(width: 12),

              // =================================================
              // POINT
              // =================================================
              Expanded(
                child: _buildStatItem(
                  'Total Point:',
                  '${data['points'] ?? '0'}',
                  'assets/icons/star.png',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          const SizedBox(height: 20),

          // ====================================================
          // ACTION MENU
          // ====================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // =================================================
              // SCAN
              // =================================================
              _buildActionItem(
                context,
                'assets/icons/scan.png',
                'Scan Barcode',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScanPage()),
                  ).then((_) => _refreshData());
                },
              ),

              // =================================================
              // TOP UP
              // =================================================
              _buildActionItem(
                context,
                'assets/icons/topup.png',
                'Top Up',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IsiSaldoPage(),
                    ),
                  ).then((_) => _refreshData());
                },
              ),

              // =================================================
              // TRANSFER
              // =================================================
              _buildActionItem(
                context,
                'assets/icons/panah.png',
                'Transfer',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransferPage(),
                    ),
                  ).then((_) => _refreshData());
                },
              ),

              // =================================================
              // HISTORY
              // =================================================
              _buildActionItem(
                context,
                'assets/icons/lock.png',
                'History',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RefundsScreen(),
                    ),
                  ).then((_) => _refreshData());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION ITEM
  // ============================================================

  Widget _buildActionItem(
    BuildContext context,
    String path,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 75,
        child: Column(
          children: [
            Image.asset(path, height: 35, width: 35),

            const SizedBox(height: 8),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A6B7D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STAT ITEM
  // ============================================================

  Widget _buildStatItem(String label, String value, String path) {
    return Row(
      children: [
        Image.asset(path, height: 35, width: 35),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3E50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTIVE PAYMENT MENU
  // ============================================================

  Widget _buildCombinedPaymentMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your active payment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3E50),
            ),
          ),

          const SizedBox(height: 15),

          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7066), Color(0xFFFF8A84)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                // ==============================================
                // DIGITAL VOUCHER
                // ==============================================
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number,
                        color: Colors.white,
                      ),

                      const SizedBox(width: 10),

                      const Text(
                        'Digital Voucher',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VoucherPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Pakai',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // MENU
                // ==============================================
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      // =========================================
                      // NEAREST RETURN POINT
                      // =========================================
                      _buildMenuTile(
                        'assets/icons/lokasi.png',
                        'Find nearest return point',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Maps(),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),

                      _buildDivider(),

                      // =========================================
                      // MARKETPLACE
                      // =========================================
                      _buildMenuTile(
                        'assets/icons/panahb.png',
                        'Exchange balance for goods',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EcomerPage(),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),

                      _buildDivider(),

                      // =========================================
                      // CHARITY
                      // =========================================
                      _buildMenuTile(
                        'assets/icons/love.png',
                        'Charities',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DonationPage(),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),

                      _buildDivider(),

                      // =========================================
                      // OTHER
                      // =========================================
                      _buildMenuTile(
                        'assets/icons/plus.png',
                        'Other',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENU TILE
  // ============================================================

  Widget _buildMenuTile(String path, String title, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Image.asset(path, height: 30, width: 30),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      color: Color(0xFFF5F5F5),
      indent: 20,
      endIndent: 20,
    );
  }
}
