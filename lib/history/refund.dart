import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  late Future<List<dynamic>> _refundsFuture;
  final Map<int, Map<String, dynamic>> _sessionDetails = {};
  final Set<int> _loadingDetails = {};

  @override
  void initState() {
    super.initState();
    _refundsFuture = _fetchRefunds();
  }

  Future<List<dynamic>> _fetchRefunds() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMySessionHistory),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['data'] ?? [];
      } else {
        throw Exception('Gagal memuat data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<void> _fetchSessionDetail(int sessionId) async {
    if (_sessionDetails.containsKey(sessionId)) return;
    
    setState(() => _loadingDetails.add(sessionId));
    
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSessionDetail(sessionId.toString())),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _sessionDetails[sessionId] = data;
          _loadingDetails.remove(sessionId);
        });
      }
    } catch (_) {
      setState(() => _loadingDetails.remove(sessionId));
    }
  }

  String _formatRupiah(dynamic price) {
    final p = (price is num)
        ? (price).toDouble()
        : double.tryParse(price.toString()) ?? 0;
    final parts = p.round().toString().split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  String _formatMonth(String? startedAt) {
    if (startedAt == null) return 'N/A';
    try {
      final date = DateTime.parse(startedAt);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  String _translateStatus(String? status) {
    switch (status) {
      case 'COMPLETED': return 'Completed';
      case 'WAITING_CONFIRMATION': return 'Waiting';
      case 'CANCELLED': return 'Cancelled';
      case 'ACTIVE': return 'Active';
      default: return status ?? 'Paid Out';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 140),
            FutureBuilder<List<dynamic>>(
              future: _refundsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(50),
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Tidak ada riwayat."));
                }
                return _buildRecapList(snapshot.data!);
              },
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildRecapList(List<dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildListHeader(),
            ListView.separated(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: data.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = data[index];
                final sessionId = item['id'];
                final monthLabel = _formatMonth(item['startedAt']);
                final location = item['machine']?['name'] ?? 'N/A';
                final amountText = _formatRupiah(item['totalPrice']);
                final statusLabel = _translateStatus(item['status']);
                
                return Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Image.asset(
                      'assets/icons/recycle.png',
                      width: 35,
                      height: 35,
                    ),
                    title: Text(
                      monthLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'Recycled at $location',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    onExpansionChanged: (expanded) {
                      if (expanded && sessionId != null) {
                        _fetchSessionDetail(sessionId);
                      }
                    },
                    children: [
                      // Session summary
                      Padding(
                        padding: const EdgeInsets.fromLTRB(72, 0, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              amountText,
                              style: const TextStyle(
                                color: Color(0xFF107569),
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF107569),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusLabel,
                                style: const TextStyle(
                                  color: Color(0xFF107569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Waste items detail
                      if (_loadingDetails.contains(sessionId))
                        const Padding(
                          padding: EdgeInsets.fromLTRB(72, 8, 20, 16),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_sessionDetails.containsKey(sessionId))
                        ..._buildWasteItems(sessionId),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWasteItems(int sessionId) {
    final detail = _sessionDetails[sessionId];
    if (detail == null) return [];
    
    final items = detail['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.fromLTRB(72, 8, 20, 16),
          child: Text(
            'No waste items found',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ];
    }

    return [
      // Header row for waste items
      const Padding(
        padding: EdgeInsets.fromLTRB(72, 8, 20, 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                'Waste Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Weight',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Price',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
      const Divider(indent: 72, endIndent: 20),
      // Waste item rows
      for (final item in items)
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 6, 20, 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  item['wasteType']?.toString() ?? 'Unknown',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${(item['weight'] is num ? (item['weight'] as num) : double.tryParse(item['weight']?.toString() ?? '0') ?? 0).toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatRupiah(item['totalPrice']),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF107569),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      // Total summary at the bottom
      const Divider(indent: 72, endIndent: 20),
      Padding(
        padding: const EdgeInsets.fromLTRB(72, 4, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: ${(detail['summary']?['currentWeight'] is num ? (detail['summary']!['currentWeight'] as num) : double.tryParse(detail['summary']?['currentWeight']?.toString() ?? '0') ?? 0).toStringAsFixed(1)} kg',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              _formatRupiah(detail['summary']?['totalPrice']),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF107569),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Color(0xFFFFD966),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: const [
          Icon(Icons.calendar_month, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            'Recap Monthly',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -110,
          left: 15,
          right: 15,
          child: _buildBalanceCard(),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              children: [
                Image.asset('assets/icons/mingcute.png', width: 45, height: 45),
                const SizedBox(width: 12),
                const Text(
                  'Refunds',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Image.asset('assets/icons/share.png', width: 45, height: 45),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                _buildInfoBox(
                  'Available balance',
                  'Rp. 0',
                  const Color(0xFFE6F9E6),
                ),
                const SizedBox(width: 10),
                _buildInfoBox(
                  'Total paid out',
                  'Rp. 0',
                  const Color(0xFFE6F2FA),
                ),
                const SizedBox(width: 10),
                _buildInfoBox(
                  'Total earnings',
                  'Rp. 0',
                  const Color(0xFFFFF9E6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
