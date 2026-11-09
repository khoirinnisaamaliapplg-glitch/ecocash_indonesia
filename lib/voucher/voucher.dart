import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class VoucherPage extends StatefulWidget {
  const VoucherPage({super.key});

  @override
  State<VoucherPage> createState() => _VoucherPageState();
}

class _VoucherPageState extends State<VoucherPage> {
  // Palet Warna Gojek-Inspired EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color brandYellowDark = Color(0xFFF5D000);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool _isLoading = true;
  String? _errorMessage;

  List<VoucherModel> _vouchers = [];
  List<VoucherModel> _filteredVouchers = [];

  final TextEditingController _searchController = TextEditingController();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // FETCH VOUCHERS (LOGIKA & INTEGRASI BE UTUH)
  // ============================================================

  Future<void> _fetchVouchers() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final Uri uri = Uri.parse('${ApiConfig.getAvailableVouchers}?limit=100');

      final http.Response response = await http.get(
        uri,
        headers: ApiConfig.headers,
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Response server tidak valid.');
      }

      if (response.statusCode != 200) {
        throw Exception(_getErrorMessage(decoded));
      }

      final List<dynamic> voucherList = _extractVoucherList(decoded);

      final List<VoucherModel> vouchers = voucherList
          .whereType()
          .map((item) => VoucherModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;

      setState(() {
        _vouchers = vouchers;
        _filteredVouchers = vouchers;
        _isLoading = false;
      });

      if (_searchController.text.trim().isNotEmpty) {
        _filterVoucher(_searchController.text);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<dynamic> _extractVoucherList(dynamic responseData) {
    if (responseData is! Map) return [];

    final Map<String, dynamic> root = Map<String, dynamic>.from(responseData);
    final dynamic data = root['data'];

    if (data is Map) {
      final Map<String, dynamic> dataMap = Map<String, dynamic>.from(data);
      final dynamic vouchers = dataMap['vouchers'];
      if (vouchers is List) return vouchers;
    }

    if (data is List) return data;

    final dynamic vouchers = root['vouchers'];
    if (vouchers is List) return vouchers;

    return [];
  }

  String _getErrorMessage(dynamic decoded) {
    if (decoded is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      if (map['message'] != null) return map['message'].toString();
      if (map['error'] != null) return map['error'].toString();
    }
    return 'Gagal mengambil voucher.';
  }

  void _filterVoucher(String keyword) {
    final String query = keyword.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredVouchers = List<VoucherModel>.from(_vouchers);
        return;
      }

      _filteredVouchers = _vouchers.where((voucher) {
        return voucher.code.toLowerCase().contains(query) ||
            voucher.name.toLowerCase().contains(query) ||
            voucher.description.toLowerCase().contains(query) ||
            voucher.storeName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _copyVoucher(VoucherModel voucher) async {
    await Clipboard.setData(ClipboardData(text: voucher.code));

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode ${voucher.code} berhasil disalin!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: textDark,
      ),
    );
  }

  void _selectVoucher(VoucherModel voucher) {
    Navigator.pop(context, {
      'id': voucher.id,
      'code': voucher.code,
      'name': voucher.name,
      'type': voucher.type,
      'value': voucher.value,
      'minSpend': voucher.minSpend,
      'maxDiscount': voucher.maxDiscount,
    });
  }

  String _getDiscountText(VoucherModel voucher) {
    if (voucher.type == 'PERCENTAGE') {
      return '${_removeTrailingZero(voucher.value)}%';
    }
    return _currencyFormatter.format(voucher.value);
  }

  String _removeTrailingZero(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _getMinSpendText(VoucherModel voucher) {
    if (voucher.minSpend <= 0) {
      return 'Tanpa minimum';
    }
    return 'Min. ${_currencyFormatter.format(voucher.minSpend)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: RefreshIndicator(
        onRefresh: _fetchVouchers,
        color: textDark,
        backgroundColor: brandYellow,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchSection()),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: primaryNavy)),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(),
              )
            else if (_filteredVouchers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      child: Column(
                        children: [
                          _buildSectionHeader(),
                          const SizedBox(height: 14),
                          ...List.generate(_filteredVouchers.length, (index) {
                            final voucher = _filteredVouchers[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildVoucherCard(voucher),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 145,
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
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: textDark),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voucher & Promo',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tukarkan poin dan hemat lebih banyak',
                        style: TextStyle(color: textDark, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _buildSearch(),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterVoucher,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, color: textDark, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Cari voucher, merchant, atau promo...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: textDark, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _filterVoucher('');
                  },
                  icon: const Icon(Icons.close, size: 18, color: textDark),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voucher Tersedia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Pilih promo yang ingin Anda gunakan',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: brandYellow.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filteredVouchers.length} Promo',
            style: const TextStyle(
              color: textDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoucherCard(VoucherModel voucher) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kolom Diskon Kiri (Kuning Gojek Signature)
              Container(
                width: 95,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFEA2E),
                      brandYellow,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_offer_rounded,
                      color: textDark,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getDiscountText(voucher),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 16,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voucher.type == 'PERCENTAGE' ? 'DISKON' : 'POTONGAN',
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Garis Pemisah Tiket (Dotted/Dashed feel)
              CustomPaint(
                size: const Size(1, double.infinity),
                painter: _DashedLinePainter(),
              ),

              // Rincian Voucher Kanan
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              voucher.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (voucher.storeName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 85),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                voucher.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (voucher.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          voucher.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Baris Kode & Tombol Salin
                      Container(
                        height: 36,
                        padding: const EdgeInsets.only(left: 10, right: 2),
                        decoration: BoxDecoration(
                          color: surfaceBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              size: 15,
                              color: textDark,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                voucher.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w900,
                                  color: textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Salin kode voucher',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _copyVoucher(voucher),
                              icon: const Icon(
                                Icons.content_copy_rounded,
                                size: 15,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Info Tambahan Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildInfoChip(
                            Icons.shopping_bag_outlined,
                            _getMinSpendText(voucher),
                          ),
                          if (voucher.type == 'PERCENTAGE' && voucher.maxDiscount != null)
                            _buildInfoChip(
                              Icons.payments_outlined,
                              'Maks. ${_currencyFormatter.format(voucher.maxDiscount)}',
                            ),
                          _buildInfoChip(
                            Icons.calendar_today_outlined,
                            's.d. ${_dateFormatter.format(voucher.validUntil)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tombol Gunakan
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () => _selectVoucher(voucher),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: textDark,
                            foregroundColor: brandYellow,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Gunakan Voucher',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 70),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: brandYellow.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                size: 30,
                color: textDark,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum Ada Voucher',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Promo dan voucher penukaran sampah akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 70),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal Memuat Voucher',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage ?? 'Terjadi kesalahan jaringan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: textDark,
              ),
              onPressed: _fetchVouchers,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// Lukis Garis Putus-Putus Pembatas Tiket Voucher
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double dashHeight = 4;
    const double dashSpace = 3;
    double startY = 0;
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ============================================================
// VOUCHER MODEL (DATA & SERIALISASI UTUH)
// ============================================================

class VoucherModel {
  final int id;
  final String code;
  final String name;
  final String description;
  final String type;

  final double value;
  final double minSpend;
  final double? maxDiscount;

  final int? storeId;
  final String storeName;

  final DateTime validFrom;
  final DateTime validUntil;

  final int perUserLimit;

  const VoucherModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.minSpend,
    required this.maxDiscount,
    required this.storeId,
    required this.storeName,
    required this.validFrom,
    required this.validUntil,
    required this.perUserLimit,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    final dynamic storeData = json['store'];

    Map<String, dynamic> store = {};
    if (storeData is Map) {
      store = Map<String, dynamic>.from(storeData);
    }

    return VoucherModel(
      id: _parseInt(json['id']),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? '',
      value: _parseDouble(json['value']),
      minSpend: _parseDouble(json['minSpend']),
      maxDiscount: json['maxDiscount'] != null ? _parseDouble(json['maxDiscount']) : null,
      storeId: json['storeId'] != null ? _parseInt(json['storeId']) : null,
      storeName: store['name']?.toString() ?? '',
      validFrom: _parseDate(json['validFrom']),
      validUntil: _parseDate(json['validUntil']),
      perUserLimit: _parseInt(json['perUserLimit']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}