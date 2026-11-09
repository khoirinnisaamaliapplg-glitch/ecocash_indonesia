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

class _IsiSaldoPageState extends State<IsiSaldoPage> with WidgetsBindingObserver {
  // Tema Warna Kuning Gojek EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool _isLoadingWallet = true;
  bool _isSubmitting = false;
  bool _isCheckingStatus = false;

  String _namaAkun = '-';
  double _balance = 0;

  String _selectedCategory = 'QRIS';
  String _selectedProvider = 'QRIS (Semua Pembayaran)';

  final Map<String, List<String>> _paymentMethods = {
    'QRIS': ['QRIS (Semua Pembayaran)'],
    'VA': ['BCA Virtual Account', 'Mandiri VA', 'BRI VA', 'BNI VA'],
    'EWALLET': ['GoPay', 'ShopeePay'],
  };

  int? _lastTopUpId;
  final TextEditingController _amountController = TextEditingController();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

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
    if (state == AppLifecycleState.resumed && _lastTopUpId != null && !_isSubmitting && !_isCheckingStatus) {
      _checkTopUpStatus(_lastTopUpId!);
    }
  }

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
    return 'User EcoCash';
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

  Future<void> _fetchWalletData() async {
    try {
      if (mounted) setState(() => _isLoadingWallet = true);

      final List<http.Response> responses = await Future.wait([
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

      final http.Response response = await http.post(
        Uri.parse(ApiConfig.createTopUp),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'amount': amount,
          'paymentMethod': _selectedProvider,
          'paymentCategory': _selectedCategory,
        }),
      );

      dynamic decoded = jsonDecode(response.body);

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

      if (mode == 'local-mock') {
        await _mockPayTopUp(topUpId);
        return;
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: RefreshIndicator(
        onRefresh: _fetchWalletData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 100),
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
          height: 260,
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
          padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: textDark),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Isi Saldo Dompet',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 130,
          left: 18,
          right: 18,
          child: _buildBalanceCard(),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A000).withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _isLoadingWallet
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(color: primaryNavy)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Akun EcoCash Warga', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(_namaAkun, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: brandYellow.withOpacity(0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: textDark, size: 22),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saldo Aktif Saat Ini', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      _currencyFormatter.format(_balance),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryNavy),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildTopUpForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 18),
              hintText: 'Minimal 10.000',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: textDark, width: 1.5)),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
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

          const Text(
            'Metode Pembayaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih jalur isi saldo yang ingin Anda gunakan.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 14),

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

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods[_selectedCategory]!.map((prov) {
              final bool isSelected = _selectedProvider == prov;
              return ChoiceChip(
                label: Text(prov),
                selected: isSelected,
                selectedColor: brandYellow,
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: textDark,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedProvider = prov);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          _buildMethodInfoBanner(),

          if (_lastTopUpId != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isCheckingStatus ? null : () => _checkTopUpStatus(_lastTopUpId!),
                icon: _isCheckingStatus
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, color: textDark),
                label: Text(
                  _isCheckingStatus ? 'Memeriksa Pembayaran...' : 'Cek Status Pembayaran',
                  style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: textDark),
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
          color: isSelected ? brandYellow.withOpacity(0.3) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? textDark : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? textDark : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: textDark,
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
          Icon(icon, size: 16, color: const Color(0xFFD97706)),
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
      selectedColor: brandYellow,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
        color: textDark,
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
          height: 52,
          child: ElevatedButton(
            onPressed: enabled ? _createTopUp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandYellow,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              foregroundColor: textDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: textDark),
                  )
                : Text(
                    enabled ? 'Bayar ${_currencyFormatter.format(amount)} via $_selectedCategory' : 'Masukkan Nominal Minimal 10.000',
                    style: TextStyle(
                      color: enabled ? textDark : Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}