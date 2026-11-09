import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../ipconfig.dart';
import 'chat_driver_page.dart';

class RiwayatPickupPage extends StatefulWidget {
  const RiwayatPickupPage({super.key});

  @override
  State<RiwayatPickupPage> createState() => _RiwayatPickupPageState();
}

class _RiwayatPickupPageState extends State<RiwayatPickupPage> with SingleTickerProviderStateMixin {
  // Tema Warna Kuning Gojek EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool _isLoading = true;
  List<dynamic> _allOrders = [];
  String _activeFilter = 'SEMUA'; // 'SEMUA', 'PROSES', 'SELESAI', 'BATAL'

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchPickupHistory();
  }

  Future<void> _fetchPickupHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getMyPickupOrders),
        headers: ApiConfig.headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List rawList = decoded['data'] is List ? decoded['data'] : [];

        final filteredList = rawList.where((item) {
          final String title = (item['title'] ?? '').toString().toLowerCase();
          if (title.contains('pengosongan container') || title.contains('kuras container')) {
            return false;
          }
          return true;
        }).toList();

        setState(() {
          _allOrders = filteredList;
        });
      } else {
        setState(() => _allOrders = []);
      }
    } catch (e) {
      debugPrint("Gagal memuat riwayat penjemputan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _displayedOrders {
    if (_activeFilter == 'PROSES') {
      return _allOrders.where((o) {
        final s = (o['status'] ?? '').toString().toUpperCase();
        return s != 'COMPLETED' && s != 'CANCELLED';
      }).toList();
    } else if (_activeFilter == 'SELESAI') {
      return _allOrders.where((o) => (o['status'] ?? '').toString().toUpperCase() == 'COMPLETED').toList();
    } else if (_activeFilter == 'BATAL') {
      return _allOrders.where((o) => (o['status'] ?? '').toString().toUpperCase() == 'CANCELLED').toList();
    }
    return _allOrders;
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return const Color(0xFFD97706);
      case 'ACCEPTED':
      case 'ON_THE_WAY':
        return const Color(0xFF0284C7);
      case 'CHECKED_IN':
      case 'PICKUP':
        return const Color(0xFF9333EA);
      case 'IN_TRANSIT':
      case 'HANDOVER':
        return const Color(0xFF4F46E5);
      case 'COMPLETED':
        return ecoGreen;
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return 'Mencari Kurir';
      case 'ACCEPTED':
        return 'Kurir Menuju Lokasi';
      case 'ON_THE_WAY':
        return 'Kurir di Jalan';
      case 'CHECKED_IN':
      case 'PICKUP':
        return 'Proses Timbang';
      case 'IN_TRANSIT':
      case 'HANDOVER':
        return 'Menuju Kontainer';
      case 'COMPLETED':
        return 'Selesai (Saldo Masuk)';
      case 'CANCELLED':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  double _parseWeight(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '') ?? 15.0;
  }

  double _resolveCitizenEarning(Map<String, dynamic> order, double weight) {
    final weightsList = order['weights'];
    if (weightsList is List && weightsList.isNotEmpty) {
      double sumSubtotal = 0;
      bool hasSubtotal = false;
      for (var w in weightsList) {
        if (w is Map && w['subtotal'] != null) {
          sumSubtotal += double.tryParse(w['subtotal'].toString()) ?? 0;
          hasSubtotal = true;
        }
      }
      if (hasSubtotal && sumSubtotal > 0) return sumSubtotal;
    }

    final rawReward = order['citizenReward'] ?? order['estimatedReward'];
    if (rawReward != null) {
      final parsed = double.tryParse(rawReward.toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    return weight * 500;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: brandYellow,
        elevation: 0,
        title: const Text(
          'Riwayat Jemput Sampah',
          style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchPickupHistory,
              color: textDark,
              backgroundColor: brandYellow,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                  : _displayedOrders.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 14),
                                  Text(
                                    _activeFilter == 'SEMUA'
                                        ? 'Belum ada riwayat penjemputan sampah.'
                                        : 'Tidak ada tugas dengan filter ini.',
                                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _displayedOrders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            return _buildOrderCard(_displayedOrders[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip('Semua (${_allOrders.length})', 'SEMUA'),
            const SizedBox(width: 8),
            _buildTabChip(
              'Dalam Proses (${_allOrders.where((o) => o['status'] != 'COMPLETED' && o['status'] != 'CANCELLED').length})',
              'PROSES',
            ),
            const SizedBox(width: 8),
            _buildTabChip(
              'Selesai (${_allOrders.where((o) => o['status'] == 'COMPLETED').length})',
              'SELESAI',
            ),
            const SizedBox(width: 8),
            _buildTabChip(
              'Batal (${_allOrders.where((o) => o['status'] == 'CANCELLED').length})',
              'BATAL',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, String value) {
    final bool isSelected = _activeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? textDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? textDark : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? brandYellow : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(dynamic rawOrder) {
    final order = Map<String, dynamic>.from(rawOrder);
    final status = (order['status'] ?? 'AVAILABLE').toString().toUpperCase();
    final bool isCompleted = status == 'COMPLETED';
    final bool isAvailable = status == 'AVAILABLE';

    final cleanAddress = (order['address'] ?? order['description'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\[PEMESAN_ID:\d+\]'), '')
        .replaceAll(RegExp(r'\[WEIGHT:[\d.]+\]'), '')
        .replaceAll(RegExp(r'\[VEHICLE:\w+\]'), '')
        .replaceAll(RegExp(r'\[TARGET_MACHINE_ID:\d+\]'), '')
        .trim();

    final targetContainer = order['targetMachineName'] ?? order['machine']?['name'] ?? 'Smart Container';
    final targetContainerArea = order['targetMachineAddress'] ?? order['machine']?['address'] ?? '';

    final double weight = _parseWeight(order['estimatedWeight'] ?? order['totalWeight']);
    final double citizenEarning = _resolveCitizenEarning(order, weight);

    final String? partnerName = order['partnerName'];
    final String? partnerPhone = order['partnerPhone'];
    final String? vehicleInfo = order['vehicleInfo'];
    final dynamic jobId = order['id'] ?? order['jobId'];
    final String createdAtStr = _formatDate(order['createdAt']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Job #$jobId • $createdAtStr',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.home_rounded, size: 16, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Titik Jemput Warga', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(cleanAddress, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.inventory_2_rounded, size: 16, color: ecoGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tujuan Kontainer / Setor', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(
                      '$targetContainer ${targetContainerArea.isNotEmpty ? "($targetContainerArea)" : ""}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ecoGreen),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Muatan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text('${weight.toStringAsFixed(1)} Kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(isCompleted ? 'Saldo Masuk ke Dompet' : 'Estimasi Saldo Warga', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(citizenEarning),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isCompleted ? ecoGreen : primaryNavy,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // SEKSI DRIVER / CHAT / KOMPLAIN
          if (partnerName != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: brandYellow,
                    child: const Icon(Icons.two_wheeler, size: 18, color: textDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kurir: $partnerName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                        Text(vehicleInfo ?? 'Driver EcoCash Partner', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDriverPage(
                            jobId: jobId,
                            driverName: partnerName,
                            driverPhone: partnerPhone,
                            vehicleInfo: vehicleInfo,
                            orderStatus: _getStatusLabel(status),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 14, color: textDark),
                    label: Text(
                      isCompleted ? 'Chat & Komplain' : 'Chat Kurir',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandYellow,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isAvailable) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.hourglass_top, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sistem sedang memanggil armada kurir terdekat ke rumah Anda...',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}