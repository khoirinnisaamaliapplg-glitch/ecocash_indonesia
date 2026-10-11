import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../ipconfig.dart';

class RiwayatPickupPage extends StatefulWidget {
  const RiwayatPickupPage({super.key});

  @override
  State<RiwayatPickupPage> createState() => _RiwayatPickupPageState();
}

class _RiwayatPickupPageState extends State<RiwayatPickupPage> {
  final Color primary = const Color(0xff0BCFD1);
  bool _isLoading = true;
  List<dynamic> _orders = [];

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

        // Filter defensif: Pastikan hanya tugas penjemputan warga (bukan Smart Container)
        final filteredList = rawList.where((item) {
          final bool hasMachine = item['machineId'] != null || item['machine'] != null;
          final String title = (item['title'] ?? '').toString().toLowerCase();

          if (hasMachine || title.contains('smart container') || title.contains('pengosongan')) {
            return false;
          }
          return true;
        }).toList();

        setState(() {
          _orders = filteredList;
        });
      } else {
        setState(() => _orders = []);
      }
    } catch (e) {
      debugPrint("Gagal memuat riwayat penjemputan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return Colors.orange;
      case 'ACCEPTED':
      case 'ON_THE_WAY':
        return Colors.blue;
      case 'CHECKED_IN':
      case 'PICKUP':
        return Colors.purple;
      case 'IN_TRANSIT':
      case 'HANDOVER':
        return Colors.indigo;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return 'Mencari Driver';
      case 'ACCEPTED':
        return 'Driver Menuju Lokasi';
      case 'ON_THE_WAY':
        return 'Driver Dalam Perjalanan';
      case 'CHECKED_IN':
      case 'PICKUP':
        return 'Proses Timbang di Lokasi';
      case 'IN_TRANSIT':
      case 'HANDOVER':
        return 'Menuju Tempat Pembuangan';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text(
          'Riwayat Jemput Sampah',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPickupHistory,
        color: primary,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primary))
            : _orders.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 70, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Belum ada riwayat penjemputan sampah.',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final status = (order['status'] ?? 'AVAILABLE').toString().toUpperCase();
                      final cleanAddress = (order['description'] ?? order['address'] ?? '')
                          .toString()
                          .replaceAll(RegExp(r'\[PEMESAN_ID:\d+\]'), '')
                          .replaceAll(RegExp(r'\[WEIGHT:[\d.]+\]'), '')
                          .replaceAll(RegExp(r'\[VEHICLE:\w+\]'), '')
                          .trim();

                      final double weight = _parseWeight(order['estimatedWeight'] ?? order['totalWeight']);
                      final double estimatedEarning = weight * 2500;

                      final String? partnerName = order['partnerName'];
                      final String? partnerPhone = order['partnerPhone'];
                      final String? vehicleInfo = order['vehicleInfo'];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    order['title'] ?? 'Penjemputan Sampah',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                            const SizedBox(height: 8),
                            Text(
                              cleanAddress,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            if (partnerName != null && status != 'AVAILABLE') ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F6F8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.two_wheeler, size: 20, color: Color(0xFF0F2C59)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Kurir: $partnerName ${vehicleInfo != null ? '($vehicleInfo)' : ''}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (partnerPhone != null)
                                      Text(
                                        partnerPhone,
                                        style: const TextStyle(fontSize: 11, color: Colors.teal),
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Estimasi Bobot', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  '${weight.toStringAsFixed(1)} Kg',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Bagi Hasil Warga', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  status == 'COMPLETED'
                                      ? '${_currencyFormat.format(estimatedEarning)} (Masuk Saldo)'
                                      : '~${_currencyFormat.format(estimatedEarning)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: status == 'COMPLETED' ? Colors.green : primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}