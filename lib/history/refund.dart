import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Alias tipe agar kebal error copy-paste kurung siku generik
typedef SessionMap = Map<String, dynamic>;

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  // Palet Warna Gojek-Inspired EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  late Future<List<SessionMap>> _sessionsFuture;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _fetchSessions();
  }

  // ============================================================
  // FETCH SESSION HISTORY (LOGIKA & INTEGRASI BE UTUH)
  // ============================================================

  Future<List<SessionMap>> _fetchSessions() async {
    final response = await http.get(
      Uri.parse(ApiConfig.getMySessionHistory),
      headers: ApiConfig.headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal memuat riwayat: ${response.statusCode}');
    }

    final dynamic decodedResponse = jsonDecode(response.body);

    if (decodedResponse is! Map<String, dynamic>) {
      throw Exception('Format respons riwayat tidak sesuai');
    }

    final dynamic rawData = decodedResponse['data'];

    if (rawData is! List) {
      return [];
    }

    final List<SessionMap> sessions = rawData
        .whereType()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final List<SessionMap> completedSessions = await Future.wait(
      sessions.map(_completeSessionData),
    );

    return completedSessions;
  }

  Future<SessionMap> _completeSessionData(SessionMap session) async {
    final SessionMap result = Map<String, dynamic>.from(session);
    final Map<String, dynamic> machine = _extractMap(session['machine']);
    result['machine'] = machine;

    final String sessionId = session['id']?.toString() ?? '';
    final int? machineId = int.tryParse(machine['id']?.toString() ?? '');

    final List<Future<void>> requests = [];

    if (sessionId.isNotEmpty) {
      requests.add(_addSessionDetail(result, sessionId));
    }

    if (machineId != null) {
      requests.add(_addMachineDetail(result, machineId));
    }

    await Future.wait(requests);

    result['currentWeight'] = _toDouble(result['currentWeight']);
    result['totalPrice'] = _toDouble(result['totalPrice']);

    return result;
  }

  Future<void> _addSessionDetail(SessionMap target, String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSessionDetail(sessionId)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode != 200) return;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final Map<String, dynamic> detail = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;

      final List<dynamic> items = detail['items'] is List
          ? List<dynamic>.from(detail['items'])
          : [];

      double itemsWeight = 0;
      double itemsPrice = 0;

      for (final dynamic rawItem in items) {
        if (rawItem is! Map) continue;
        final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
        itemsWeight += _toDouble(item['weight']);
        itemsPrice += _toDouble(item['totalPrice']);
      }

      final Map<String, dynamic> summary = _extractMap(detail['summary']);
      final double summaryWeight = _toDouble(summary['currentWeight']);
      final double summaryPrice = _toDouble(summary['totalPrice']);
      final double historyWeight = _toDouble(target['currentWeight']);
      final double historyPrice = _toDouble(target['totalPrice']);

      target['currentWeight'] = itemsWeight > 0
          ? itemsWeight
          : summaryWeight > 0
              ? summaryWeight
              : historyWeight;

      target['totalPrice'] = itemsPrice > 0
          ? itemsPrice
          : summaryPrice > 0
              ? summaryPrice
              : historyPrice;

      if (detail['status'] != null) target['status'] = detail['status'];
      if (detail['startedAt'] != null) target['startedAt'] = detail['startedAt'];
      if (detail['endedAt'] != null) target['endedAt'] = detail['endedAt'];

      target['items'] = items;
    } catch (error) {
      debugPrint('Gagal mengambil detail sesi $sessionId: $error');
    }
  }

  Future<void> _addMachineDetail(SessionMap target, int machineId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMachineById(machineId)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode != 200) return;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final Map<String, dynamic> machineDetail = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;

      final Map<String, dynamic> oldMachine = _extractMap(target['machine']);
      target['machine'] = {...oldMachine, ...machineDetail};
    } catch (error) {
      debugPrint('Gagal mengambil detail mesin $machineId: $error');
    }
  }

  Map<String, dynamic> _extractMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  Future<void> _refreshSessions() async {
    final Future<List<SessionMap>> newFuture = _fetchSessions();
    setState(() {
      _sessionsFuture = newFuture;
    });
    await newFuture;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '-';
    try {
      final DateTime date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  String _formatSessionDate(SessionMap session) {
    final dynamic dateValue = session['startedAt'] ?? session['createdAt'];
    return _formatDate(dateValue);
  }

  String _getMachineName(SessionMap session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);
    final String name = machine['name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : 'Smart Container';
  }

  String _getMachineCode(SessionMap session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);
    final String machineCode = machine['machineCode']?.toString().trim() ?? '';
    return machineCode.isNotEmpty ? machineCode : '-';
  }

  String _getMachineLocation(SessionMap session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);
    final String placeName = machine['placeName']?.toString().trim() ?? '';
    final String address = machine['address']?.toString().trim() ?? '';
    final String subdistrict = machine['subdistrict']?.toString().trim() ?? '';
    final String district = machine['district']?.toString().trim() ?? '';

    if (placeName.isNotEmpty && address.isNotEmpty) {
      return '$placeName, $address';
    }
    if (address.isNotEmpty) return address;
    if (placeName.isNotEmpty) return placeName;

    final List<String> locationParts = [subdistrict, district].where((v) => v.isNotEmpty).toList();
    if (locationParts.isNotEmpty) return locationParts.join(', ');

    return 'Lokasi tidak tersedia';
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'Sedang Berlangsung';
      case 'WAITING_CONFIRMATION':
        return 'Menunggu Konfirmasi';
      case 'COMPLETED':
        return 'Selesai (Saldo Masuk)';
      case 'CANCELLED':
        return 'Dibatalkan';
      case 'EXPIRED':
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF0284C7);
      case 'WAITING_CONFIRMATION':
        return const Color(0xFFD97706);
      case 'COMPLETED':
        return ecoGreen;
      case 'CANCELLED':
      case 'EXPIRED':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: FutureBuilder<List<SessionMap>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          final List<SessionMap> sessions = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refreshSessions,
            color: textDark,
            backgroundColor: brandYellow,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(context, sessions),
                  const SizedBox(height: 70),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(color: primaryNavy),
                    )
                  else if (snapshot.hasError)
                    _buildErrorState(snapshot.error.toString())
                  else if (sessions.isEmpty)
                    _buildEmptyState()
                  else
                    _buildSessionList(sessions),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark),
            onPressed: _refreshSessions,
            child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 50),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 60, color: Colors.grey),
          SizedBox(height: 14),
          Text(
            'Belum ada riwayat setoran Smart Container.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(List<SessionMap> sessions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildListHeader(sessions.length),
              ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: sessions.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) => _buildSessionItem(sessions[index]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionItem(SessionMap session) {
    final String status = session['status']?.toString() ?? 'UNKNOWN';
    final Color statusColor = _statusColor(status);
    final double currentWeight = _toDouble(session['currentWeight']);
    final double totalPrice = _toDouble(session['totalPrice']);
    final String machineName = _getMachineName(session);
    final String machineCode = _getMachineCode(session);
    final String machineLocation = _getMachineLocation(session);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: brandYellow.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.inventory_2_rounded, color: textDark, size: 22),
        ),
        title: Text(
          machineName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(_formatSessionDate(session), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const Spacer(),
              Text(
                _currencyFormat.format(totalPrice),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: ecoGreen),
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _detailRow(label: 'Kode Mesin', value: machineCode),
                const Divider(height: 18),
                _detailRow(label: 'Lokasi Setor', value: machineLocation),
                const Divider(height: 18),
                _detailRow(
                  label: 'Total Muatan',
                  value: '${currentWeight.toStringAsFixed(2)} kg',
                ),
                const Divider(height: 18),
                _detailRow(
                  label: 'Bagi Hasil Diterima',
                  value: _currencyFormat.format(totalPrice),
                  valueColor: ecoGreen,
                ),
                const Divider(height: 18),
                _detailRow(
                  label: 'Waktu Mulai',
                  value: _formatDate(session['startedAt'] ?? session['createdAt']),
                ),
                if (session['endedAt'] != null) ...[
                  const Divider(height: 18),
                  _detailRow(
                    label: 'Waktu Selesai',
                    value: _formatDate(session['endedAt']),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? textDark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: textDark),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long_rounded, color: brandYellow, size: 20),
              SizedBox(width: 8),
              Text(
                'Daftar Transaksi Setoran',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          Text(
            '$count Sesi',
            style: const TextStyle(color: brandYellow, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<SessionMap> sessions) {
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
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: textDark),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Riwayat Setor Sampah',
                      style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: 18,
          right: 18,
          child: _buildSummaryCard(sessions),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<SessionMap> sessions) {
    final int totalSessions = sessions.length;
    final double totalWeight = sessions.fold<double>(0, (total, session) {
      return total + _toDouble(session['currentWeight']);
    });
    final double totalEarnings = sessions.fold<double>(0, (total, session) {
      return total + _toDouble(session['totalPrice']);
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A000).withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Akumulasi Kontribusi', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('Setoran Smart Container', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: brandYellow.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.insights_rounded, color: textDark, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoBox('Total Sesi', '$totalSessions kali', const Color(0xFFF1F5F9)),
              const SizedBox(width: 8),
              _buildInfoBox('Total Muatan', '${totalWeight.toStringAsFixed(1)} kg', const Color(0xFFFEF3C7)),
              const SizedBox(width: 8),
              _buildInfoBox('Bagi Hasil', _currencyFormat.format(totalEarnings), const Color(0xFFDCFCE7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}