import 'package:flutter/material.dart';
import 'package:ecocash_indonesia/home.dart';
import 'package:ecocash_indonesia/setor_sampah/scan.dart';

class TransaksiBerhasilScreen extends StatelessWidget {
  final Map<String, dynamic>? detailTransaksi;

  const TransaksiBerhasilScreen({super.key, this.detailTransaksi});

  String _formatNumber(dynamic val) {
    if (val == null) return '0';
    final n = double.tryParse(val.toString()) ?? 0;
    return n.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = detailTransaksi?['data'] ?? {};
    final List items = data['items'] is List ? data['items'] : [];
    final String earned = data['earned']?.toString() ?? '0';
    final String balance = data['balance']?.toString() ?? '0';
    final String sessionId = data['sessionId']?.toString() ?? '-';
    final String totalWeight = data['totalWeight']?.toString() ?? '0.00';
    final String machineName = data['machineName']?.toString() ?? 'Smart Container';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _buildHeader(context),
                Positioned(
                  top: 130,
                  left: 20,
                  right: 20,
                  child: _buildSuccessCard(items, earned, balance, sessionId, totalWeight, machineName),
                ),
              ],
            ),
            const SizedBox(height: 520),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
        image: DecorationImage(
          image: AssetImage('assets/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
      child: const Text(
        'Bukti Setor Sampah',
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSuccessCard(
    List items,
    String earned,
    String balance,
    String idSesi,
    String totalWeight,
    String machineName,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Transaksi Berhasil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Saldo hasil setoran telah masuk ke dompet Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Banner Komisi Masuk
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Saldo Diterima', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
                const SizedBox(height: 4),
                Text(
                  '+Rp ${_formatNumber(earned)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Saldo Dompet Saat Ini: Rp ${_formatNumber(balance)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF388E3C)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Detail Rincian Sampah
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lokasi: $machineName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('ID Sesi: #$idSesi', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                const Divider(height: 20),

                if (items.isEmpty)
                  const Text("Detail sampah tidak ditemukan", style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  Column(
                    children: items.map((item) {
                      final name = item['wasteType'] ?? 'Material';
                      final weight = item['weight'] ?? '0';
                      final price = item['totalPrice'] ?? '0';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.recycling, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('$name ($weight kg)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                            Text('Rp ${_formatNumber(price)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Muatan Bersih', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('$totalWeight Kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const ScanPage()),
                (route) => route.isFirst,
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4CAF50)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Setor Sampah Lagi', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}