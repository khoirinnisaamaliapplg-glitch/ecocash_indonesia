import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class IsiSaldoPage extends StatefulWidget {
  const IsiSaldoPage({super.key});

  @override
  State<IsiSaldoPage> createState() => _IsiSaldoPageState();
}

class _IsiSaldoPageState extends State<IsiSaldoPage>
    with WidgetsBindingObserver {
  // ============================================================
  // STATE
  // ============================================================

  bool _isLoadingWallet = true;
  bool _isSubmitting = false;
  bool _isCheckingStatus = false;

  String _namaAkun = '-';
  double _balance = 0;

  // Pilihan Metode Top Up
  String _selectedCategory = 'QRIS'; // 'QRIS', 'VA', 'EWALLET'
  String _selectedProvider = 'QRIS (Semua Pembayaran)';

  final Map<String, List<String>> _paymentMethods = {
    'QRIS': ['QRIS (Semua Pembayaran)'],
    'VA': ['BCA Virtual Account', 'Mandiri VA', 'BRI VA', 'BNI VA'],
    'EWALLET': ['GoPay', 'ShopeePay'],
  };

  /// Menyimpan ID top-up terakhir untuk cek status setelah kembali dari browser
  int? _lastTopUpId;

  final TextEditingController _amountController = TextEditingController();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // ============================================================
  // INIT & LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchWalletData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        _lastTopUpId != null &&
        !_isSubmitting &&
        !_isCheckingStatus) {
      _checkTopUpStatus(_lastTopUpId!);
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _extractDataMap(dynamic responseData) {
    if (responseData is! Map) return {};
    final Map<String, dynamic> responseMap = Map<String, dynamic>.from(responseData);
    final dynamic data = responseMap['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return responseMap;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  String _getUserName(Map<String, dynamic> data) {
    final String name = data['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final String username = data['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) return username;
    return 'User';
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _getErrorMessage(dynamic decoded) {
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      if (map['message'] != null) return map['message'].toString();
      if (map['error'] != null) return map['error'].toString();
    }
    return 'Terjadi kesalahan pada server.';
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // ============================================================
  // FETCH USER + WALLET
  // ============================================================

  Future<void> _fetchWalletData() async {
    try {
      if (mounted) setState(() => _isLoadingWallet = true);

      final List<http.Response> responses = await Future.wait<http.Response>([
        http.get(Uri.parse(ApiConfig.getUserProfile), headers: ApiConfig.headers),
        http.get(Uri.parse(ApiConfig.getMyWallet), headers: ApiConfig.headers),
      ]);

      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw Exception('Gagal memuat profil atau saldo dompet');
      }

      final Map<String, dynamic> profileData = _extractDataMap(jsonDecode(responses[0].body));
      final Map<String, dynamic> walletData = _extractDataMap(jsonDecode(responses[1].body));

      if (!mounted) return;
      setState(() {
        _namaAkun = _getUserName(profileData);
        _balance = _parseNumber(walletData['balance']);
        _isLoadingWallet = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingWallet = false);
      _showMessage('Gagal mengambil data: $e', error: true);
    }
  }

  // ============================================================
  // CREATE TOP UP
  // ============================================================

  Future<void> _createTopUp() async {
    FocusScope.of(context).unfocus();

    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int? amount = int.tryParse(rawAmount);

    if (amount == null || amount < 10000) {
      _showMessage('Minimal nominal isi saldo adalah Rp 10.000', error: true);
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      // Kirim amount dan preferensi metode pembayaran yang dipilih
      final http.Response response = await http.post(
        Uri.parse(ApiConfig.createTopUp),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'amount': amount,
          'paymentMethod': _selectedProvider,
          'paymentCategory': _selectedCategory,
        }),
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Response server tidak valid.');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_getErrorMessage(decoded));
      }

      final Map<String, dynamic> data = _extractDataMap(decoded);
      final dynamic idValue = data['id'];

      if (idValue == null) throw Exception('ID top up tidak ditemukan.');
      final int? topUpId = int.tryParse(idValue.toString());
      if (topUpId == null) throw Exception('ID top up tidak valid.');

      _lastTopUpId = topUpId;

      final String mode = data['mode']?.toString().trim() ?? '';

      // Mode pengujian lokal tanpa payment gateway
      if (mode == 'local-mock') {
        await _mockPayTopUp(topUpId);
        return;
      }

      // Midtrans Snap Redirect
      final String redirectUrl = data['redirectUrl']?.toString().trim() ?? '';
      if (redirectUrl.isEmpty) {
        throw Exception('URL pembayaran Midtrans tidak ditemukan.');
      }

      final Uri paymentUri = Uri.parse(redirectUrl);
      final bool launched = await launchUrl(paymentUri, mode: LaunchMode.externalApplication);

      if (!launched) {
        throw Exception('Tidak dapat membuka halaman pembayaran Midtrans.');
      }

      _showMessage('Menuju gateway pembayaran ($_selectedProvider)...');
    } catch (e) {
      _showMessage('Top up gagal: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _mockPayTopUp(int topUpId) async {
    try {
      final http.Response response = await http.post(
        Uri.parse(ApiConfig.mockPayTopUp(topUpId)),
        headers: ApiConfig.headers,
      );

      dynamic decoded = jsonDecode(response.body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_getErrorMessage(decoded));
      }

      _showMessage('Top up via $_selectedProvider berhasil disimulasikan!');
      _amountController.clear();
      _lastTopUpId = null;
      await _fetchWalletData();
    } catch (e) {
      _showMessage('Mock payment gagal: $e', error: true);
    }
  }

  Future<void> _checkTopUpStatus(int topUpId) async {
    if (_isCheckingStatus) return;

    try {
      if (mounted) setState(() => _isCheckingStatus = true);

      final http.Response response = await http.post(
        Uri.parse(ApiConfig.checkTopUpStatus(topUpId)),
        headers: ApiConfig.headers,
      );

      dynamic decoded = jsonDecode(response.body);
      if (response.statusCode != 200) throw Exception(_getErrorMessage(decoded));

      final Map<String, dynamic> result = _extractDataMap(decoded);
      final Map<String, dynamic> topUp = _toMap(result['topup']);
      final String status = topUp['status']?.toString().toUpperCase().trim() ?? '';

      if (status == 'COMPLETED') {
        _showMessage('Pembayaran berhasil! Saldo telah ditambahkan ke dompet.');
        _lastTopUpId = null;
        _amountController.clear();
        await _fetchWalletData();
        return;
      }

      if (status == 'FAILED') {
        _showMessage('Pembayaran dibatalkan atau gagal.', error: true);
        _lastTopUpId = null;
        return;
      }

      _showMessage('Pembayaran masih menunggu penyelesaian transaksi.');
    } catch (e) {
      _showMessage('Gagal memeriksa pembayaran: $e', error: true);
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _fetchWalletData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 105),
              _buildTopUpForm(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xff0BCFD1),
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(width: 15),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Isi Saldo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 150,
          left: 20,
          right: 20,
          child: _buildBalanceCard(),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _isLoadingWallet
          ? const SizedBox(
              height: 110,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nama Akun',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  _namaAkun,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                ),
                const Text(
                  'Saldo Aktif',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xff0BCFD1).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Color(0xff0BCFD1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _currencyFormatter.format(_balance),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildTopUpForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nominal Isi Saldo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3E50)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixText: 'Rp ',
              hintText: 'Minimal 10.000',
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [10000, 20000, 50000, 100000, 200000, 500000].map((amt) {
              return _buildNominalButton(amt);
            }).toList(),
          ),

          const Divider(height: 32),

          // ====================================================
          // METODE PEMBAYARAN
          // ====================================================
          const Text(
            'Metode Pembayaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3E50)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih jalur isi saldo yang ingin Anda gunakan.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 14),

          // Tab Kategori (QRIS, Virtual Account, E-Wallet)
          Row(
            children: [
              Expanded(
                child: _buildCategoryTab('QRIS', 'QRIS', Icons.qr_code_scanner),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryTab('VA', 'Transfer Bank', Icons.account_balance),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryTab('EWALLET', 'E-Wallet', Icons.account_balance_wallet_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pilihan Provider Channel
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods[_selectedCategory]!.map((prov) {
              final bool isSelected = _selectedProvider == prov;
              return ChoiceChip(
                label: Text(prov),
                selected: isSelected,
                selectedColor: const Color(0xff0BCFD1),
                backgroundColor: const Color(0xFFF4F6F8),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedProvider = prov);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Banner Penjelasan Metode
          _buildMethodInfoBanner(),

          // ====================================================
          // STATUS CHECK BUTTON
          // ====================================================
          if (_lastTopUpId != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isCheckingStatus ? null : () => _checkTopUpStatus(_lastTopUpId!),
                icon: _isCheckingStatus
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(_isCheckingStatus ? 'Memeriksa Pembayaran...' : 'Cek Status Pembayaran'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String cat, String label, IconData icon) {
    final bool isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = cat;
          _selectedProvider = _paymentMethods[cat]!.first;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff0BCFD1).withOpacity(0.12) : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xff0BCFD1) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? const Color(0xff0BCFD1) : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xff0BCFD1) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodInfoBanner() {
    String message = '';
    IconData icon = Icons.info_outline;

    if (_selectedCategory == 'QRIS') {
      message = 'Bisa dibayar instan dari semua m-Banking (BCA, Mandiri, BRI, BNI) & E-Wallet (GoPay, DANA, OVO, ShopeePay).';
      icon = Icons.qr_code;
    } else if (_selectedCategory == 'VA') {
      message = 'Nomor Virtual Account unik akan digenerate otomatis. Bebas transfer 24 jam dengan verifikasi instan.';
      icon = Icons.account_balance;
    } else {
      message = 'Anda akan diarahkan langsung ke aplikasi e-wallet terpilih untuk konfirmasi pembayaran cepat.';
      icon = Icons.account_balance_wallet;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xff0BCFD1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNominalButton(int amount) {
    final String currentAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final bool selected = currentAmount == amount.toString();

    return ChoiceChip(
      selected: selected,
      label: Text(_currencyFormatter.format(amount)),
      selectedColor: const Color(0xff0BCFD1),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: selected ? Colors.white : Colors.black87,
      ),
      onSelected: (_) {
        setState(() {
          _amountController.text = amount.toString();
          _amountController.selection = TextSelection.fromPosition(
            TextPosition(offset: _amountController.text.length),
          );
        });
      },
    );
  }

  Widget _buildBottomBar() {
    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int amount = int.tryParse(rawAmount) ?? 0;
    final bool enabled = !_isSubmitting && !_isLoadingWallet && amount >= 10000;

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: enabled ? _createTopUp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0BCFD1),
              disabledBackgroundColor: const Color(0xFFD3D3D3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    enabled ? 'Bayar ${_currencyFormatter.format(amount)} via $_selectedCategory' : 'Masukkan Nominal Valid',
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}