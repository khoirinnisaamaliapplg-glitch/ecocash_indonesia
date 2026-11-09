import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/transaksi.dart';

// Alias tipe agar kebal terhadap error copy-paste kurung bertingkat
typedef WasteItemMap = Map<String, dynamic>;

class SetorSampahScreen extends StatefulWidget {
  final int sessionId;
  final WasteItemMap? initialSessionData;

  const SetorSampahScreen({
    super.key,
    required this.sessionId,
    this.initialSessionData,
  });

  @override
  State<SetorSampahScreen> createState() => _SetorSampahScreenState();
}

class _SetorSampahScreenState extends State<SetorSampahScreen> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool _isLoading = false;
  bool _isReadyToConfirm = false;
  String _statusMesin = "Silakan masukkan botol/sampah Anda ke lubang mesin...";
  Timer? _timer;

  List<WasteItemMap> _wasteItems = [];
  double _currentTotalWeight = 0.0;
  double _currentTotalPrice = 0.0;
  String? _machineName;
  String? _machineCode;

  int _secondsElapsed = 0;
  final int _maxSeconds = 600;

  @override
  void initState() {
    super.initState();
    if (widget.initialSessionData != null) {
      _applySessionData(widget.initialSessionData!);
    }
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _applySessionData(WasteItemMap data) {
    final String status = (data['status'] ?? '').toString().trim().toUpperCase();
    final dynamic rawItems = data['items'];
    final List<dynamic> items = rawItems is List ? rawItems : [];

    final double totalWeight = double.tryParse((data['summary']?['currentWeight'] ?? 0).toString()) ?? 0.0;
    final double totalPrice = double.tryParse((data['summary']?['totalPrice'] ?? 0).toString()) ?? 0.0;

    final dynamic machine = data['machine'];
    if (machine is Map) {
      _machineName = machine['name']?.toString();
      _machineCode = machine['machineCode']?.toString();
    }

    setState(() {
      _wasteItems = items.map<WasteItemMap>((item) {
        String typeName = 'Material';
        if (item is Map) {
          if (item['wasteType'] is Map) {
            typeName = item['wasteType']['name'] ?? 'Material';
          } else if (item['wasteType'] != null) {
            typeName = item['wasteType'].toString();
          }

          return {
            'wasteType': typeName,
            'weight': (item['weight'] ?? '0').toString(),
            'totalPrice': (item['totalPrice'] ?? '0').toString(),
            'pricePerKg': (item['pricePerKg'] ?? '0').toString(),
          };
        }
        return {
          'wasteType': 'Material',
          'weight': '0',
          'totalPrice': '0',
          'pricePerKg': '0',
        };
      }).toList();

      _currentTotalWeight = totalWeight;
      _currentTotalPrice = totalPrice;

      if (status == 'WAITING_CONFIRMATION') {
        _isReadyToConfirm = true;
        _statusMesin = "Mesin selesai menimbang! Silakan konfirmasi untuk menerima saldo.";
      } else if (status == 'ACTIVE') {
        _statusMesin = _wasteItems.isEmpty
            ? "Pintu mesin terbuka. Masukkan botol/sampah Anda..."
            : "Sedang menimbang muatan sampah...";
      }
    });
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _secondsElapsed += 2;
      if (!mounted || _secondsElapsed >= _maxSeconds) {
        timer.cancel();
        return;
      }

      try {
        var response = await http.get(
          Uri.parse(ApiConfig.getCurrentSession),
          headers: ApiConfig.headers,
        );

        if (response.statusCode != 200) {
          response = await http.get(
            Uri.parse(ApiConfig.getSessionDetail(widget.sessionId.toString())),
            headers: ApiConfig.headers,
          );
        }

        if (response.statusCode == 200 && mounted) {
          final body = jsonDecode(response.body);
          final dynamic data = body['data'];
          if (data is Map) {
            final WasteItemMap sessionData = Map<String, dynamic>.from(data);
            _applySessionData(sessionData);
            if ((sessionData['status'] ?? '').toString().toUpperCase() == 'WAITING_CONFIRMATION' && !_isReadyToConfirm) {
              HapticFeedback.heavyImpact();
              setState(() => _isReadyToConfirm = true);
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _handleConfirm() async {
    if (!_isReadyToConfirm) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.confirmSession(widget.sessionId.toString())),
        headers: ApiConfig.headers,
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _timer?.cancel();
        final dynamic confirmData = body['data'] ?? {};

        final WasteItemMap successPayload = {
          'sessionId': widget.sessionId.toString(),
          'earned': confirmData['earned']?.toString() ?? _currentTotalPrice.toStringAsFixed(0),
          'balance': confirmData['balance']?.toString() ?? '0',
          'totalWeight': _currentTotalWeight.toStringAsFixed(2),
          'machineName': _machineName ?? 'Smart Container',
          'machineCode': _machineCode ?? '',
          'items': _wasteItems,
        };

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TransaksiBerhasilScreen(detailTransaksi: {'data': successPayload}),
          ),
          (route) => route.isFirst,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: brandYellow,
        elevation: 0,
        title: Text(
          _machineName != null ? 'Setor - $_machineName' : 'Setor Sampah',
          style: const TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Column(
                children: [
                  if (!_isReadyToConfirm) ...[
                    const CircularProgressIndicator(color: textDark),
                    const SizedBox(height: 14),
                  ] else ...[
                    const Icon(Icons.check_circle, color: ecoGreen, size: 48),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    _statusMesin,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _isReadyToConfirm ? ecoGreen : textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.recycling, color: ecoGreen, size: 22),
                      const SizedBox(width: 8),
                      const Text('Sampah Terdeteksi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                        child: Text('${_wasteItems.length} Item', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (_wasteItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: Text('Masukkan botol sampah Anda satu per satu ke lubang mesin.', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    )
                  else
                    ..._wasteItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text(item['wasteType'] ?? 'Material', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark))),
                            Text('${item['weight'] ?? 0} kg', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(width: 14),
                            Text('Rp ${item['totalPrice'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: ecoGreen)),
                          ],
                        ),
                      );
                    }),

                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Timbangan', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('${_currentTotalWeight.toStringAsFixed(2)} Kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimasi Bagi Hasil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textDark)),
                      Text(
                        'Rp ${_currentTotalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ecoGreen),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(18.0),
        child: ElevatedButton(
          onPressed: (_isReadyToConfirm && !_isLoading) ? _handleConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: brandYellow,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            foregroundColor: textDark,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: textDark, strokeWidth: 2))
              : Text(
                  _isReadyToConfirm ? "Konfirmasi & Terima Saldo" : "Menunggu Mesin Selesai...",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
        ),
      ),
    );
  }
}