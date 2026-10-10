import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  bool isBrowseActive = true;

  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _charities = [];
  List<Map<String, dynamic>> _myDonations = [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _selectedCategory = 'Latest';

  int? _donatingCharityId;

  @override
  void initState() {
    super.initState();
    _fetchPublicCharities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ============================================================
  // GET PUBLIC CHARITIES
  // ============================================================

  Future<void> _fetchPublicCharities({String? search}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, String> query = {};

      final keyword = search?.trim() ?? '';

      if (keyword.isNotEmpty) {
        query['search'] = keyword;
      }

      switch (_selectedCategory) {
        case 'Top Donate':
          query['sortBy'] = 'collectedAmount';
          query['sortOrder'] = 'desc';
          break;

        case 'Latest':
          query['sortBy'] = 'createdAt';
          query['sortOrder'] = 'desc';
          break;

        case 'Urgent':
          query['sortBy'] = 'createdAt';
          query['sortOrder'] = 'desc';
          break;
      }

      Uri uri = Uri.parse(ApiConfig.getPublicCharities);

      if (query.isNotEmpty) {
        uri = uri.replace(queryParameters: query);
      }

      debugPrint('================ CHARITY ================');
      debugPrint('GET CHARITIES : $uri');
      debugPrint('HAS TOKEN     : ${ApiConfig.hasToken}');
      debugPrint(
        'AUTH HEADER   : ${ApiConfig.headers['Authorization'] != null}',
      );
      debugPrint('=========================================');

      // INI BAGIAN YANG DIPERBAIKI
      final response = await http.get(uri, headers: ApiConfig.headers);

      debugPrint('CHARITIES STATUS: ${response.statusCode}');
      debugPrint('CHARITIES BODY  : ${response.body}');

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> data = _extractList(
          response.body,
          'charities',
        );

        if (_selectedCategory == 'Urgent') {
          data.sort((a, b) {
            final aDate = DateTime.tryParse(a['endAt']?.toString() ?? '');

            final bDate = DateTime.tryParse(b['endAt']?.toString() ?? '');

            if (aDate == null && bDate == null) {
              return 0;
            }

            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return aDate.compareTo(bDate);
          });
        }

        if (!mounted) return;

        setState(() {
          _charities = data;
        });
      } else {
        throw Exception(
          _extractErrorMessage(
            response.body,
            'Gagal mengambil daftar bantuan.',
          ),
        );
      }
    } catch (e) {
      debugPrint('GET CHARITIES ERROR: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // GET MY DONATIONS
  // ============================================================

  Future<void> _fetchMyDonations() async {
    final token = ApiConfig.userToken;

    if (token == null || token.trim().isEmpty) {
      setState(() {
        _myDonations = [];
        _errorMessage = 'Sesi login tidak ditemukan. Silakan login kembali.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMyDonations),
        headers: ApiConfig.headers,
      );

      debugPrint('MY DONATION STATUS: ${response.statusCode}');
      debugPrint('MY DONATION BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = _extractList(response.body, 'donations');

        if (!mounted) return;

        setState(() {
          _myDonations = data;
        });
      } else {
        throw Exception(
          _extractErrorMessage(
            response.body,
            'Gagal mengambil riwayat donasi.',
          ),
        );
      }
    } catch (e) {
      debugPrint('GET MY DONATIONS ERROR: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // DONATE
  // ============================================================

  Future<void> _submitDonation({
    required int charityId,
    required double amount,
    String? message,
  }) async {
    final token = ApiConfig.userToken;

    if (token == null || token.trim().isEmpty) {
      _showSnackBar('Silakan login terlebih dahulu.', isError: true);
      return;
    }

    setState(() {
      _donatingCharityId = charityId;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.donateToCharity(charityId)),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'amount': amount,
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        }),
      );

      debugPrint('DONATION STATUS: ${response.statusCode}');
      debugPrint('DONATION BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        _showSnackBar('Donasi berhasil. Terima kasih atas bantuan Anda.');

        // Refresh progress charity setelah donasi.
        await _fetchPublicCharities(search: _searchController.text);
      } else {
        final message = _extractErrorMessage(response.body, 'Donasi gagal.');

        if (!mounted) return;

        _showSnackBar(message, isError: true);
      }
    } catch (e) {
      debugPrint('DONATION ERROR: $e');

      if (!mounted) return;

      _showSnackBar('Terjadi kesalahan saat melakukan donasi.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _donatingCharityId = null;
        });
      }
    }
  }

  // ============================================================
  // DONATION BOTTOM SHEET
  // ============================================================

  Future<void> _openDonationSheet(Map<String, dynamic> charity) async {
    final token = ApiConfig.userToken;

    if (token == null || token.trim().isEmpty) {
      _showSnackBar(
        'Silakan login terlebih dahulu untuk berdonasi.',
        isError: true,
      );
      return;
    }

    final amountController = TextEditingController();
    final messageController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 22,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 25,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Beri Bantuan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(
                  charity['name']?.toString() ?? 'Program Bantuan',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nominal Donasi',
                    prefixText: 'Rp ',
                    hintText: '10000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Pesan (opsional)',
                    hintText: 'Semoga bantuan ini bermanfaat...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A745),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final rawAmount = amountController.text
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .trim();

                      final amount = double.tryParse(rawAmount);

                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Masukkan nominal donasi yang valid.',
                            ),
                          ),
                        );

                        return;
                      }

                      Navigator.pop(bottomSheetContext, {
                        'amount': amount,
                        'message': messageController.text.trim(),
                      });
                    },
                    child: const Text(
                      'Konfirmasi Donasi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    amountController.dispose();
    messageController.dispose();

    if (result == null) return;

    final charityId = _toInt(charity['id']);

    if (charityId == null) {
      _showSnackBar('Charity ID tidak valid.', isError: true);
      return;
    }

    await _submitDonation(
      charityId: charityId,
      amount: (result['amount'] as num).toDouble(),
      message: result['message']?.toString(),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (isBrowseActive) {
        _fetchPublicCharities(search: value);
      }
    });
  }

  // ============================================================
  // SWITCH TAB
  // ============================================================

  Future<void> _switchTab(bool browse) async {
    if (isBrowseActive == browse) return;

    setState(() {
      isBrowseActive = browse;
      _errorMessage = null;
    });

    if (browse) {
      await _fetchPublicCharities(search: _searchController.text);
    } else {
      await _fetchMyDonations();
    }
  }

  Future<void> _refreshCurrentPage() async {
    if (isBrowseActive) {
      await _fetchPublicCharities(search: _searchController.text);
    } else {
      await _fetchMyDonations();
    }
  }

  // ============================================================
  // PARSER RESPONSE
  // ============================================================

  List<Map<String, dynamic>> _extractList(String body, String key) {
    final decoded = jsonDecode(body);

    dynamic payload = decoded;

    if (decoded is Map<String, dynamic> && decoded['data'] != null) {
      payload = decoded['data'];
    }

    dynamic rawList;

    if (payload is Map) {
      rawList = payload[key];
    } else {
      rawList = payload;
    }

    if (rawList is! List) {
      return [];
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _extractErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        return decoded['message']?.toString() ??
            decoded['error']?['message']?.toString() ??
            fallback;
      }
    } catch (_) {}

    return fallback;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: RefreshIndicator(
        onRefresh: _refreshCurrentPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    if (isBrowseActive) ...[
                      _buildSearchAndFilter(),
                      const SizedBox(height: 25),
                      _buildCategoryTabs(),
                      const SizedBox(height: 25),
                    ] else ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Riwayat Donasi Saya',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    _buildContent(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: _refreshCurrentPage,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (isBrowseActive) {
      if (_charities.isEmpty) {
        return _buildEmptyState(
          icon: Icons.volunteer_activism_outlined,
          title: 'Belum ada program bantuan',
          subtitle: 'Program bantuan sosial aktif akan tampil di sini.',
        );
      }

      return Column(
        children: [
          for (int i = 0; i < _charities.length; i++) ...[
            _buildCharityCard(_charities[i]),
            if (i != _charities.length - 1) const SizedBox(height: 20),
          ],
        ],
      );
    }

    if (_myDonations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'Belum ada riwayat donasi',
        subtitle: 'Donasi yang Anda lakukan akan muncul di sini.',
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _myDonations.length; i++) ...[
          _buildMyDonationCard(_myDonations[i]),
          if (i != _myDonations.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Bantuan Sosial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 85,
          left: 20,
          right: 20,
          child: Container(
            height: 55,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildToggleItem(
                  'My Donation',
                  !isBrowseActive,
                  () => _switchTab(false),
                ),
                _buildToggleItem(
                  'Browse Charities',
                  isBrowseActive,
                  () => _switchTab(true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.grey[600],
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Cari program bantuan...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  Widget _buildCategoryTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _categoryItem('Latest', Icons.watch_later),
        _categoryItem('Urgent', Icons.notifications_active_outlined),
        _categoryItem('Top Donate', Icons.emoji_events_outlined),
      ],
    );
  }

  Widget _categoryItem(String label, IconData icon) {
    final active = _selectedCategory == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });

        _fetchPublicCharities(search: _searchController.text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE1F5FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.blue),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CHARITY CARD
  // ============================================================

  Widget _buildCharityCard(Map<String, dynamic> charity) {
    final id = _toInt(charity['id']);

    final title = charity['name']?.toString() ?? 'Program Bantuan';

    final foundation = charity['foundation'];

    final foundationName = foundation is Map
        ? foundation['name']?.toString() ?? 'Foundation'
        : 'Foundation';

    final imageUrl = charity['imageUrl']?.toString();

    final target = _toDouble(charity['targetAmount']);

    final collected = _toDouble(charity['collectedAmount']);

    final donationCount = _toInt(charity['donationCount']) ?? 0;

    final status = charity['status']?.toString() ?? 'ACTIVE';

    final progressPercent = _toDouble(charity['progressPercent']);

    double progress;

    if (progressPercent > 0) {
      progress = progressPercent / 100;
    } else if (target > 0) {
      progress = collected / target;
    } else {
      progress = 0;
    }

    progress = progress.clamp(0.0, 1.0);

    final isClosed = status != 'ACTIVE';

    final isDonating = id != null && _donatingCharityId == id;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 4),

                    if (isClosed)
                      Text(
                        _formatStatus(status),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 4),

                    Text(
                      'Foundation:',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),

                    Text(
                      'by $foundationName',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% dari target Rp ${_formatNumber(target)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isClosed ? Colors.redAccent : const Color(0xFF28A745),
                        ),
                        minHeight: 6,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Terkumpul Rp ${_formatNumber(collected)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isClosed ? Icons.favorite_border : Icons.favorite,
                    color: isClosed ? Colors.grey : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$donationCount Donations',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              ElevatedButton(
                onPressed: isClosed || isDonating || id == null
                    ? null
                    : () {
                        _openDonationSheet(charity);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A745),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE0E0E0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: isDonating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Donate now'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MY DONATION CARD
  // ============================================================

  Widget _buildMyDonationCard(Map<String, dynamic> donation) {
    final charity = donation['charity'];

    final charityName = charity is Map
        ? charity['name']?.toString() ?? 'Program Bantuan'
        : 'Program Bantuan';

    String foundationName = '-';

    if (charity is Map && charity['foundation'] is Map) {
      foundationName = charity['foundation']['name']?.toString() ?? '-';
    }

    final amount = _toDouble(donation['amount']);

    final message = donation['message']?.toString();

    final createdAt = donation['createdAt']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.favorite, color: Color(0xFF28A745)),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charityName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  foundationName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),

                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '"$message"',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                if (createdAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            'Rp ${_formatNumber(amount)}',
            style: const TextStyle(
              color: Color(0xFF28A745),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPER WIDGET
  // ============================================================

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.volunteer_activism, color: Colors.grey, size: 40),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 60, color: Colors.grey[350]),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _formatNumber(double number) {
    final value = number.round().toString();

    return value.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'COMPLETED':
        return 'Target Tercapai';
      case 'CLOSED':
        return 'Closed';
      default:
        return status;
    }
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF28A745),
        ),
      );
  }
}
