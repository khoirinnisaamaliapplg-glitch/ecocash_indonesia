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
  // FETCH VOUCHERS
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

      debugPrint('GET VOUCHER: $uri');

      final http.Response response = await http.get(
        uri,
        headers: ApiConfig.headers,
      );

      debugPrint('VOUCHER STATUS: ${response.statusCode}');

      debugPrint('VOUCHER BODY: ${response.body}');

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
          .whereType<Map>()
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

  // ============================================================
  // RESPONSE PARSER
  // ============================================================

  List<dynamic> _extractVoucherList(dynamic responseData) {
    if (responseData is! Map) {
      return [];
    }

    final Map<String, dynamic> root = Map<String, dynamic>.from(responseData);

    final dynamic data = root['data'];

    if (data is Map) {
      final Map<String, dynamic> dataMap = Map<String, dynamic>.from(data);

      final dynamic vouchers = dataMap['vouchers'];

      if (vouchers is List) {
        return vouchers;
      }
    }

    if (data is List) {
      return data;
    }

    final dynamic vouchers = root['vouchers'];

    if (vouchers is List) {
      return vouchers;
    }

    return [];
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _getErrorMessage(dynamic decoded) {
    if (decoded is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

      if (map['message'] != null) {
        return map['message'].toString();
      }

      if (map['error'] != null) {
        return map['error'].toString();
      }
    }

    return 'Gagal mengambil voucher.';
  }

  // ============================================================
  // SEARCH
  // ============================================================

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

  // ============================================================
  // COPY VOUCHER
  // ============================================================

  Future<void> _copyVoucher(VoucherModel voucher) async {
    await Clipboard.setData(ClipboardData(text: voucher.code));

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode ${voucher.code} berhasil disalin'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // SELECT VOUCHER
  // ============================================================

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

  // ============================================================
  // FORMAT
  // ============================================================

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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _fetchVouchers,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ==================================================
            // HEADER
            // ==================================================
            SliverToBoxAdapter(child: _buildHeader()),

            // ==================================================
            // SEARCH DI BAWAH HEADER
            // ==================================================
            SliverToBoxAdapter(child: _buildSearchSection()),

            // ==================================================
            // CONTENT
            // ==================================================
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
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

                          const SizedBox(height: 15),

                          ...List.generate(_filteredVouchers.length, (index) {
                            final voucher = _filteredVouchers[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      height: 145,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/bg.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================================================
              // BACK BUTTON
              // =================================================
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // =================================================
              // TITLE
              // =================================================
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voucher',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: 4),

                      Text(
                        'Temukan promo terbaik untukmu',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
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

  // ============================================================
  // SEARCH SECTION
  // ============================================================

  Widget _buildSearchSection() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: _buildSearch(),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterVoucher,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, color: Color(0xFF263746)),
        decoration: InputDecoration(
          hintText: 'Cari voucher...',
          hintStyle: const TextStyle(color: Color(0xFFA3ABB3), fontSize: 12),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF768390),
            size: 19,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();

                    _filterVoucher('');
                  },
                  icon: const Icon(Icons.close, size: 18),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF263746),
                ),
              ),

              SizedBox(height: 3),

              Text(
                'Pilih promo yang ingin digunakan',
                style: TextStyle(fontSize: 11, color: Color(0xFF8B959E)),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F7FC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filteredVouchers.length} Promo',
            style: const TextStyle(
              color: Color(0xFF189DCC),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VOUCHER CARD
  // ============================================================

  Widget _buildVoucherCard(VoucherModel voucher) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDF0F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==================================================
            // LEFT AREA
            // ==================================================
            Container(
              width: 105,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF22B6E8), Color(0xFF54D2F4)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white,
                    size: 26,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _getDiscountText(voucher),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    voucher.type == 'PERCENTAGE' ? 'DISKON' : 'POTONGAN',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===========================================
                    // NAME
                    // ===========================================
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            voucher.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF263746),
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        if (voucher.storeName.isNotEmpty) ...[
                          const SizedBox(width: 6),

                          Container(
                            constraints: const BoxConstraints(maxWidth: 85),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FAFD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              voucher.storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF159DCB),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // ===========================================
                    // DESCRIPTION
                    // ===========================================
                    if (voucher.description.isNotEmpty) ...[
                      const SizedBox(height: 5),

                      Text(
                        voucher.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7B8790),
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: 11),

                    // ===========================================
                    // CODE
                    // ===========================================
                    Container(
                      height: 38,
                      padding: const EdgeInsets.only(left: 10, right: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FA),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFE8ECEF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            size: 16,
                            color: Color(0xFF25AAD8),
                          ),

                          const SizedBox(width: 7),

                          Expanded(
                            child: Text(
                              voucher.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF364956),
                              ),
                            ),
                          ),

                          IconButton(
                            tooltip: 'Salin kode',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _copyVoucher(voucher);
                            },
                            icon: const Icon(
                              Icons.content_copy_rounded,
                              size: 16,
                              color: Color(0xFF25AAD8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===========================================
                    // INFO
                    // ===========================================
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(
                          Icons.shopping_bag_outlined,
                          _getMinSpendText(voucher),
                        ),

                        if (voucher.type == 'PERCENTAGE' &&
                            voucher.maxDiscount != null)
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

                    const SizedBox(height: 13),

                    // ===========================================
                    // BUTTON
                    // ===========================================
                    SizedBox(
                      width: double.infinity,
                      height: 39,
                      child: ElevatedButton(
                        onPressed: () {
                          _selectVoucher(voucher);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF32B5E2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Gunakan Voucher',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF7D8992)),

          const SizedBox(width: 4),

          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7D8992),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 0, 30, 70),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF8FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  size: 34,
                  color: Color(0xFF35B6E9),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Belum Ada Voucher',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF263746),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Promo dan voucher yang tersedia akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: Color(0xFF8B959E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 0, 30, 70),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEEEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 34,
                  color: Colors.redAccent,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Gagal Memuat Voucher',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 6),

              Text(
                _errorMessage ?? 'Terjadi kesalahan.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _fetchVouchers,
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// VOUCHER MODEL
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

      maxDiscount: json['maxDiscount'] != null
          ? _parseDouble(json['maxDiscount'])
          : null,

      storeId: json['storeId'] != null ? _parseInt(json['storeId']) : null,

      storeName: store['name']?.toString() ?? '',

      validFrom: _parseDate(json['validFrom']),

      validUntil: _parseDate(json['validUntil']),

      perUserLimit: _parseInt(json['perUserLimit']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
