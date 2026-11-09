import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';

// Alias tipe agar kebal terhadap pemotongan teks copy-paste
typedef CharityMap = Map<String, dynamic>;

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  // Palet Warna Gojek-Inspired EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color brandYellowDark = Color(0xFFF5D000);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool isBrowseActive = true;
  bool _isLoading = false;
  String? _errorMessage;

  List<CharityMap> _charities = [];
  List<CharityMap> _myDonations = [];

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

  Future<void> _fetchPublicCharities({String? search}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, String> query = {};
      final keyword = search?.trim() ?? '';
      if (keyword.isNotEmpty) query['search'] = keyword;

      switch (_selectedCategory) {
        case 'Top Donate':
          query['sortBy'] = 'collectedAmount';
          query['sortOrder'] = 'desc';
          break;
        case 'Latest':
        case 'Urgent':
        default:
          query['sortBy'] = 'createdAt';
          query['sortOrder'] = 'desc';
          break;
      }

      query['_t'] = DateTime.now().millisecondsSinceEpoch.toString();

      Uri uri = Uri.parse(ApiConfig.getPublicCharities);
      uri = uri.replace(queryParameters: query);

      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        List<CharityMap> data = _extractList(response.body, 'charities');

        if (_selectedCategory == 'Urgent') {
          data.sort((a, b) {
            final aDate = DateTime.tryParse(a['endAt']?.toString() ?? '');
            final bDate = DateTime.tryParse(b['endAt']?.toString() ?? '');
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
        }

        if (!mounted) return;
        setState(() => _charities = data);
      } else {
        throw Exception(_extractErrorMessage(response.body, 'Gagal mengambil daftar bantuan.'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

      if (response.statusCode == 200) {
        final data = _extractList(response.body, 'donations');
        if (!mounted) return;
        setState(() => _myDonations = data);
      } else {
        throw Exception(_extractErrorMessage(response.body, 'Gagal mengambil riwayat donasi.'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

    setState(() => _donatingCharityId = charityId);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.donateToCharity(charityId)),
        headers: {
          ...ApiConfig.headers,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showSnackBar('Donasi Rp ${_formatNumber(amount)} berhasil disalurkan.');
        await _fetchPublicCharities(search: _searchController.text);
      } else {
        final messageErr = _extractErrorMessage(response.body, 'Donasi gagal.');
        if (!mounted) return;
        _showSnackBar(messageErr, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan saat melakukan donasi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _donatingCharityId = null);
    }
  }

  Future<void> _openDonationSheet(CharityMap charity) async {
    final token = ApiConfig.userToken;
    if (token == null || token.trim().isEmpty) {
      _showSnackBar('Silakan login terlebih dahulu untuk berdonasi.', isError: true);
      return;
    }

    double userBalance = 0.0;
    try {
      final walletRes = await http.get(Uri.parse(ApiConfig.getMyWallet), headers: ApiConfig.headers);
      if (walletRes.statusCode == 200) {
        final dynamic wData = jsonDecode(walletRes.body);
        final dynamic payload = wData is Map ? (wData['data'] ?? wData) : {};
        final rawBal = payload is Map ? payload['balance'] : 0;
        userBalance = (rawBal is num) ? rawBal.toDouble() : double.tryParse(rawBal.toString()) ?? 0.0;
      }
    } catch (_) {}

    final amountController = TextEditingController();
    final messageController = TextEditingController();

    if (!mounted) return;

    // Tanpa kurung sudut generik agar bebas dari kerusakan copy-paste
    final dynamic result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
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
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: brandYellow.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.volunteer_activism_rounded, color: textDark, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Beri Bantuan Sosial',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark),
                              ),
                              Text(
                                charity['name']?.toString() ?? 'Program Bantuan',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kartu Saldo Dompet Warga
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: primaryNavy, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Saldo Dompet EcoCash', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(
                                  'Rp ${_formatNumber(userBalance)}',
                                  style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Aktif', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Nominal
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nominal Donasi',
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 16),
                        hintText: 'Minimal 1.000',
                        filled: true,
                        fillColor: surfaceBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: textDark, width: 1.5)),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textDark),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Quick Nominal Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [5000, 10000, 25000, 50000].map((amt) {
                        return ActionChip(
                          label: Text('Rp ${_formatNumber(amt.toDouble())}'),
                          backgroundColor: surfaceBg,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                          onPressed: () {
                            setSheetState(() {
                              amountController.text = amt.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: messageController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Pesan / Doa Kebaikan (Opsional)',
                        hintText: 'Semoga bantuan ini membawa berkah...',
                        filled: true,
                        fillColor: surfaceBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandYellow,
                          foregroundColor: textDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final rawAmount = amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
                          final amount = double.tryParse(rawAmount);

                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                              const SnackBar(content: Text('Masukkan nominal donasi yang valid.')),
                            );
                            return;
                          }

                          if (amount > userBalance) {
                            ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                              SnackBar(
                                content: Text('Saldo dompet tidak mencukupi (Rp ${_formatNumber(userBalance)}).'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(bottomSheetContext, {
                            'amount': amount,
                            'message': messageController.text.trim(),
                          });
                        },
                        child: const Text('Konfirmasi & Salurkan Donasi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    messageController.dispose();

    if (result == null || result is! Map) return;
    final charityId = _toInt(charity['id']);
    if (charityId == null) return;

    await _submitDonation(
      charityId: charityId,
      amount: (result['amount'] as num).toDouble(),
      message: result['message']?.toString(),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (isBrowseActive) _fetchPublicCharities(search: value);
    });
  }

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

  List<CharityMap> _extractList(String body, String key) {
    try {
      final decoded = jsonDecode(body);
      dynamic payload = decoded;

      if (decoded is Map) {
        if (decoded['data'] != null) {
          payload = decoded['data'];
        }
      }

      dynamic rawList;

      if (payload is List) {
        rawList = payload;
      } else if (payload is Map) {
        rawList = payload[key] ??
            payload['charities'] ??
            payload['items'] ??
            payload['data'] ??
            payload['rows'] ??
            payload['list'] ??
            payload['result'];
      }

      if (rawList is! List && decoded is Map) {
        rawList = decoded['charities'] ?? decoded['items'] ?? decoded['data'];
      }

      if (rawList is! List) return [];

      return rawList
          .whereType()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error parsing charity: $e');
      return [];
    }
  }

  String _extractErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded['message']?.toString() ?? decoded['error']?['message']?.toString() ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: RefreshIndicator(
        onRefresh: _refreshCurrentPage,
        color: textDark,
        backgroundColor: brandYellow,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    const SizedBox(height: 34),
                    if (isBrowseActive) ...[
                      _buildSearchAndFilter(),
                      const SizedBox(height: 18),
                      _buildCategoryTabs(),
                      const SizedBox(height: 20),
                    ] else ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Riwayat Kebaikan Saya',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildContent(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: primaryNavy)),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark),
              onPressed: _refreshCurrentPage,
              child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
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
            if (i != _charities.length - 1) const SizedBox(height: 16),
          ],
        ],
      );
    }

    if (_myDonations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Belum ada riwayat donasi',
        subtitle: 'Donasi yang Anda lakukan dari saldo daur ulang akan muncul di sini.',
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _myDonations.length; i++) ...[
          _buildMyDonationCard(_myDonations[i]),
          if (i != _myDonations.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 250,
          width: double.infinity,
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: textDark),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Bantuan & Donasi Sosial',
                    style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: -22,
          left: 18,
          right: 18,
          child: Container(
            height: 52,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                _buildToggleItem('Jelajah Program', isBrowseActive, () => _switchTab(true)),
                _buildToggleItem('Riwayat Donasi', !isBrowseActive, () => _switchTab(false)),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive ? textDark : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? brandYellow : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Cari program bantuan lingkungan / kemanusiaan...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _categoryItem('Latest', 'Terbaru', Icons.schedule_rounded),
          const SizedBox(width: 8),
          _categoryItem('Urgent', 'Mendesak', Icons.bolt_rounded),
          const SizedBox(width: 8),
          _categoryItem('Top Donate', 'Paling Banyak Dibantu', Icons.emoji_events_rounded),
        ],
      ),
    );
  }

  Widget _categoryItem(String key, String label, IconData icon) {
    final active = _selectedCategory == key;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = key);
        _fetchPublicCharities(search: _searchController.text);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? brandYellow : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? textDark : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: textDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharityCard(CharityMap charity) {
    final id = _toInt(charity['id']);
    final title = charity['name']?.toString() ?? 'Program Bantuan';
    final foundation = charity['foundation'];
    final foundationName = foundation is Map ? foundation['name']?.toString() ?? 'Yayasan Mitra' : 'Yayasan Mitra';
    final imageUrl = charity['imageUrl']?.toString();
    final target = _toDouble(charity['targetAmount']);
    final collected = _toDouble(charity['collectedAmount']);
    final donationCount = _toInt(charity['donationCount']) ?? 0;
    final status = charity['status']?.toString() ?? 'ACTIVE';
    final progressPercent = _toDouble(charity['progressPercent']);

    double progress = progressPercent > 0 ? progressPercent / 100 : (target > 0 ? collected / target : 0);
    progress = progress.clamp(0.0, 1.0);

    final isClosed = status != 'ACTIVE';
    final isDonating = id != null && _donatingCharityId == id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder())
                      : _imagePlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            foundationName,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isClosed) ...[
                      const SizedBox(height: 4),
                      Text(_formatStatus(status), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Baris Progres & Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terkumpul Rp ${_formatNumber(collected)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: textDark),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ecoGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(isClosed ? Colors.grey : ecoGreen),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Target: Rp ${_formatNumber(target)}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),

          const Divider(height: 22),

          // Baris Aksi & Jumlah Donatur
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 18),
                  const SizedBox(width: 6),
                  Text('$donationCount Donasi Masuk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textDark)),
                ],
              ),
              ElevatedButton(
                onPressed: isClosed || isDonating || id == null ? null : () => _openDonationSheet(charity),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  foregroundColor: textDark,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isDonating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: textDark))
                    : const Text('Bantu Sekarang', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyDonationCard(CharityMap donation) {
    final charity = donation['charity'];
    final charityName = charity is Map ? charity['name']?.toString() ?? 'Program Bantuan' : 'Program Bantuan';
    String foundationName = '-';
    if (charity is Map && charity['foundation'] is Map) {
      foundationName = charity['foundation']['name']?.toString() ?? '-';
    }
    final amount = _toDouble(donation['amount']);
    final message = donation['message']?.toString();
    final createdAt = donation['createdAt']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandYellow.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite_rounded, color: textDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(charityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                const SizedBox(height: 2),
                Text('Penyalur: $foundationName', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('"$message"', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic)),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(_formatDate(createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rp ${_formatNumber(amount)}',
            style: const TextStyle(color: ecoGreen, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Icon(Icons.volunteer_activism_rounded, color: Colors.grey, size: 36),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          Icon(icon, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    final value = number.round().toString();
    return value.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'COMPLETED':
        return 'Target Tercapai';
      case 'CLOSED':
        return 'Program Selesai';
      default:
        return status;
    }
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF00AA13),
        ),
      );
  }
}