import 'package:flutter/material.dart';
import 'package:ecocash_indonesia/home.dart';
import 'package:ecocash_indonesia/setor_sampah/scan.dart';

class TransaksiBerhasilScreen extends StatelessWidget {
  final Map<String, dynamic>? detailTransaksi;

  const TransaksiBerhasilScreen({super.key, this.detailTransaksi});

  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color ecoGreen = Color(0xFF00AA13);

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
    final String confirmedBy = (data['confirmedBy'] ?? '').toString().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _buildHeader(context),
                Positioned(
                  top: 110,
                  left: 18,
                  right: 18,
                  child: _buildSuccessCard(items, earned, balance, sessionId, totalWeight, machineName, confirmedBy),
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
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
      child: const Text(
        'Bukti Setor Sampah',
        style: TextStyle(color: textDark, fontSize: 22, fontWeight: FontWeight.w900),
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
    String confirmedBy,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Setor Sampah Berhasil!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
              SizedBox(width: 8),
              Icon(Icons.check_circle, color: ecoGreen, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            confirmedBy == 'MACHINE' ? 'Dikonfirmasi melalui layar Smart Container. Saldo telah masuk ke dompet Anda.' : 'Saldo hasil setoran telah masuk ke dompet Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Saldo Diterima', style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '+Rp ${_formatNumber(earned)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF14532D)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saldo Dompet Sekarang: Rp ${_formatNumber(balance)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

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
                    Text('Lokasi: $machineName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark)),
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.recycling, size: 16, color: ecoGreen),
                            const SizedBox(width: 8),
                            Expanded(child: Text('$name ($weight kg)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            Text('Rp ${_formatNumber(price)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textDark)),
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
                    Text('$totalWeight Kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textDark)),
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
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
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
              backgroundColor: brandYellow,
              foregroundColor: textDark,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Kembali ke Beranda', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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
              side: const BorderSide(color: textDark),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Setor Sampah Lagi', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}