import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/scan.dart';
import 'package:ecocash_indonesia/pickupwaste/pickup_waste.dart';

class EcoPointsPage extends StatefulWidget {
  const EcoPointsPage({super.key});

  @override
  State<EcoPointsPage> createState() => _EcoPointsPageState();
}

class _EcoPointsPageState extends State<EcoPointsPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool _isLoading = true;
  int _points = 0;
  int _lifetimePoints = 0;
  String _tier = 'EcoStarter';
  String? _nextTier;
  int? _nextTierPoints;
  List _transactions = [];
  List _charities = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchPointsData(),
      _fetchCharities(),
    ]);
  }

  Future<void> _fetchPointsData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getMyPoints),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : {};
        final summary = data is Map && data['summary'] is Map ? data['summary'] : {};
        final list = data is Map && data['transactions'] is List ? data['transactions'] : [];

        if (mounted) {
          setState(() {
            _points = int.tryParse(summary['points']?.toString() ?? '0') ?? 0;
            _lifetimePoints = int.tryParse(summary['lifetimePoints']?.toString() ?? '0') ?? 0;
            _tier = summary['tier']?.toString() ?? 'EcoStarter';
            _nextTier = summary['nextTier']?.toString();
            _nextTierPoints = int.tryParse(summary['nextTierPoints']?.toString() ?? '');
            _transactions = list;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCharities() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getPublicCharities),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawData = decoded is Map ? decoded['data'] : decoded;
        List list = [];
        if (rawData is List) {
          list = rawData;
        } else if (rawData is Map && rawData['charities'] is List) {
          list = rawData['charities'];
        } else if (rawData is Map && rawData['items'] is List) {
          list = rawData['items'];
        }

        final activeList = list.whereType().where((item) {
          final status = (item['status'] ?? 'ACTIVE').toString().toUpperCase();
          final isActive = item['isActive'] ?? true;
          return status == 'ACTIVE' && isActive == true;
        }).map((e) => Map.from(e)).toList();

        if (mounted) {
          setState(() {
            _charities = activeList;
          });
        }
      }
    } catch (_) {}
  }

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _openRedeemModal() {
    int selectedPoints = 1000;
    String selectedTarget = 'WALLET';
    int? selectedCharityId = _charities.isNotEmpty
        ? int.tryParse(_charities.first['id']?.toString() ?? '')
        : null;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final int rupiahEstimate = selectedPoints;

            Future<void> submitRedeem() async {
              if (_points < selectedPoints) {
                _showSnack('Saldo poin Anda belum mencukupi.', isError: true);
                return;
              }
              if (selectedTarget == 'DONATION' && selectedCharityId == null) {
                _showSnack('Silakan pilih program donasi terlebih dahulu.', isError: true);
                return;
              }

              setModalState(() => isSubmitting = true);
              try {
                final payload = {
                  'points': selectedPoints,
                  'target': selectedTarget,
                  if (selectedTarget == 'DONATION' && selectedCharityId != null)
                    'charityId': selectedCharityId,
                };

                final res = await http.post(
                  Uri.parse(ApiConfig.redeemPoints),
                  headers: ApiConfig.headers,
                  body: jsonEncode(payload),
                );
                final decoded = jsonDecode(res.body);

                if (res.statusCode == 200 || res.statusCode == 201) {
                  final resData = decoded is Map && decoded['data'] is Map ? decoded['data'] : {};
                  final charityName = resData['charityName']?.toString() ?? 'EcoDonasi';

                  if (modalCtx.mounted) Navigator.pop(modalCtx);
                  _showSnack(
                    selectedTarget == 'WALLET'
                        ? 'Berhasil menukar ${_formatNumber(selectedPoints)} poin menjadi Rp${_formatNumber(rupiahEstimate)}!'
                        : 'Terima kasih! ${_formatNumber(selectedPoints)} poin didonasikan ke $charityName.',
                  );
                  await _fetchPointsData();
                } else {
                  final msg = decoded is Map
                      ? (decoded['message']?.toString() ?? 'Gagal menukar poin')
                      : 'Gagal menukar poin';
                  _showSnack(msg, isError: true);
                }
              } catch (e) {
                _showSnack('Kesalahan koneksi: $e', isError: true);
              } finally {
                if (ctx.mounted) setModalState(() => isSubmitting = false);
              }
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tukar EcoPoints',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark),
                      ),
                      Text(
                        'Poin aktif Anda: ${_formatNumber(_points)} poin (1.000 poin = Rp1.000)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Pilih Tujuan Penukaran',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTargetOption(
                              label: 'Saldo EcoCash',
                              subtitle: 'Masuk dompet utama',
                              icon: Icons.account_balance_wallet_rounded,
                              selected: selectedTarget == 'WALLET',
                              onTap: () => setModalState(() => selectedTarget = 'WALLET'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTargetOption(
                              label: 'EcoDonasi',
                              subtitle: 'Program penghijauan',
                              icon: Icons.volunteer_activism_rounded,
                              selected: selectedTarget == 'DONATION',
                              onTap: () => setModalState(() => selectedTarget = 'DONATION'),
                            ),
                          ),
                        ],
                      ),

                      if (selectedTarget == 'DONATION') ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Pilih Program Donasi Tujuan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark),
                        ),
                        const SizedBox(height: 6),
                        if (_charities.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Belum ada kampanye EcoDonasi aktif yang tersedia.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            initialValue: selectedCharityId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: surfaceBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            items: _charities.map((c) {
                              final int id = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
                              final String name = c['name']?.toString() ?? 'Program Donasi #$id';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() => selectedCharityId = val);
                            },
                          ),
                      ],

                      const SizedBox(height: 16),
                      const Text(
                        'Pilih Nominal Poin',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [1000, 2000, 5000, 10000, 25000].map((pts) {
                          final bool active = selectedPoints == pts;
                          return ChoiceChip(
                            selected: active,
                            selectedColor: brandYellow,
                            backgroundColor: surfaceBg,
                            label: Text(
                              '${_formatNumber(pts)} Poin',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: active ? textDark : Colors.grey.shade700,
                              ),
                            ),
                            onSelected: (_) => setModalState(() => selectedPoints = pts),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surfaceBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Nilai Konversi:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Rp${_formatNumber(rupiahEstimate)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: ecoGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : submitRedeem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandYellow,
                            foregroundColor: textDark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: textDark),
                                )
                              : Text(
                                  'Tukar ${_formatNumber(selectedPoints)} Poin Sekarang',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTargetOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? brandYellow.withValues(alpha: 0.25) : surfaceBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? textDark : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: textDark, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: textDark),
            ),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_nextTierPoints != null && _nextTierPoints! > 0)
        ? (_lifetimePoints / _nextTierPoints!).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: brandYellow,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EcoPoints & Keanggotaan',
          style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: textDark,
        backgroundColor: brandYellow,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: textDark))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: brandYellow,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.stars_rounded, size: 15, color: textDark),
                                  const SizedBox(width: 4),
                                  Text(
                                    _tier,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _openRedeemModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandYellow,
                                foregroundColor: textDark,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Tukar Poin',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_formatNumber(_points)} Poin',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Setara Rp${_formatNumber(_points)} • Akumulasi: ${_formatNumber(_lifetimePoints)} poin',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        if (_nextTier != null && _nextTierPoints != null) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(brandYellow),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kumpulkan ${_formatNumber((_nextTierPoints! - _lifetimePoints).clamp(0, 999999))} poin lagi menuju $_nextTier',
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Cara Mendapatkan EcoPoints',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 10),
                  _buildEarnSchemeCard(
                    icon: Icons.qr_code_scanner_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Setor Mandiri via Smart Container (QR)',
                    reward: '+100 Poin / kg',
                    subtitle: 'Tunjukkan atau pindai QR akun di mesin RVM untuk poin instan.',
                    buttonLabel: 'Pindai QR',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScanPage()),
                      ).then((_) => _fetchPointsData());
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildEarnSchemeCard(
                    icon: Icons.local_shipping_rounded,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: ecoGreen,
                    title: 'Setor Sampah via Mitra Kurir (EcoJemput)',
                    reward: '+75 Poin / kg',
                    subtitle: 'Poin otomatis masuk setelah kurir menimbang & menyetor sampah.',
                    buttonLabel: 'Pesan Jemput',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PickupWastePage()),
                      ).then((_) => _fetchPointsData());
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Riwayat Mutasi Poin',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
                  ),
                  const SizedBox(height: 10),
                  if (_transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Belum ada riwayat poin. Mulai setor sampah via QR Smart Container atau Mitra EcoJemput!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    ..._transactions.map((tx) {
                      final int pts = int.tryParse(tx['points']?.toString() ?? '0') ?? 0;
                      final bool isEarn = pts >= 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isEarn
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              child: Icon(
                                isEarn ? Icons.add_circle_outline : Icons.redeem_rounded,
                                color: isEarn ? ecoGreen : const Color(0xFFD97706),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx['description']?.toString() ?? 'Mutasi Poin',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sisa poin: ${_formatNumber(int.tryParse(tx['pointsAfter']?.toString() ?? '0') ?? 0)}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isEarn ? '+' : ''}${_formatNumber(pts)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: isEarn ? ecoGreen : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildEarnSchemeCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String reward,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: textDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        reward,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: ecoGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onTap,
                  child: Text(
                    '$buttonLabel →',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: primaryNavy,
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

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? Colors.red.shade700 : ecoGreen,
          content: Text(message),
        ),
      );
  }
}