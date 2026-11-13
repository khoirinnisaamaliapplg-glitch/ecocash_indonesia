import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/transaksi.dart';

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
  bool _isSocketConnected = false;
  bool _hasCompletedNavigation = false;
  String _statusMesin = "Silakan masukkan botol/sampah Anda ke lubang mesin...";

  IO.Socket? _socket;
  Timer? _fallbackTimer;

  List<WasteItemMap> _wasteItems = [];
  final Set<int> _seenItemIds = {};
  double _currentTotalWeight = 0.0;
  double _currentTotalPrice = 0.0;
  String? _machineName;
  String? _machineCode;

  @override
  void initState() {
    super.initState();
    if (widget.initialSessionData != null) {
      _applySessionData(widget.initialSessionData!);
    }
    _initSessionSocket();
    _syncSessionSnapshot();
    _startFallbackSync();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _disposeSocket();
    super.dispose();
  }

  void _disposeSocket() {
    if (_socket != null) {
      _socket!.off('connect');
      _socket!.off('disconnect');
      _socket!.off('ready');
      _socket!.off('session:item');
      _socket!.off('session:state');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  void _navigateToSuccess({
    String? earned,
    String? balance,
    String? pointsEarned,
    String? pointsBalance,
    String? confirmedBy,
  }) {
    if (!mounted || _hasCompletedNavigation) return;
    _hasCompletedNavigation = true;
    _fallbackTimer?.cancel();
    _disposeSocket();

    HapticFeedback.heavyImpact();

    final WasteItemMap successPayload = {
      'sessionId': widget.sessionId.toString(),
      'earned': earned ?? _currentTotalPrice.toStringAsFixed(0),
      'balance': balance ?? '0',
      'pointsEarned': pointsEarned ?? '0',
      'pointsBalance': pointsBalance ?? '0',
      if (confirmedBy != null) 'confirmedBy': confirmedBy,
      'totalWeight': _currentTotalWeight.toStringAsFixed(2),
      'machineName': _machineName ?? 'Smart Container',
      'machineCode': _machineCode ?? '',
      'items': _wasteItems,
    };

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => TransaksiBerhasilScreen(detailTransaksi: {'data': successPayload}),
      ),
      (route) => route.isFirst,
    );
  }

  void _handleSessionCancelled() {
    if (!mounted || _hasCompletedNavigation) return;
    _hasCompletedNavigation = true;
    _fallbackTimer?.cancel();
    _disposeSocket();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesi penyetoran dibatalkan atau berakhir karena tidak ada aktivitas.'),
        backgroundColor: Colors.orange,
      ),
    );
    Navigator.pop(context);
  }

  void _initSessionSocket() {
    final token = ApiConfig.userToken?.trim() ?? '';
    if (token.isEmpty) return;

    _disposeSocket();

    final socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    socket.onConnect((_) {
      if (mounted) setState(() => _isSocketConnected = true);
      _syncSessionSnapshot();
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() => _isSocketConnected = false);
    });

    // Event live setiap kali user memasukkan sampah ke mesin RVM
    socket.on('session:item', (payload) {
      if (!mounted || _hasCompletedNavigation || payload is! Map) return;
      final int? eventSessionId = int.tryParse((payload['sessionId'] ?? '').toString());
      if (eventSessionId != null && eventSessionId != widget.sessionId) return;

      final dynamic rawItem = payload['item'];
      if (rawItem is! Map) return;

      final int? itemId = int.tryParse((rawItem['id'] ?? payload['seq'] ?? '').toString());
      if (itemId != null && _seenItemIds.contains(itemId)) return;

      String typeName = 'Material';
      if (rawItem['wasteType'] is Map) {
        typeName = rawItem['wasteType']['name']?.toString() ?? 'Material';
      } else if (rawItem['wasteType'] != null) {
        typeName = rawItem['wasteType'].toString();
      }

      final double itemWeight = double.tryParse((rawItem['weight'] ?? 0).toString()) ?? 0.0;
      final double itemPrice = double.tryParse((rawItem['totalPrice'] ?? 0).toString()) ?? 0.0;

      HapticFeedback.lightImpact();

      setState(() {
        if (itemId != null) _seenItemIds.add(itemId);
        _wasteItems.add({
          if (itemId != null) 'id': itemId,
          'wasteType': typeName,
          'weight': itemWeight.toString(),
          'totalPrice': itemPrice.toString(),
          'pricePerKg': (rawItem['pricePerKg'] ?? '0').toString(),
        });
        _currentTotalWeight = double.parse((_currentTotalWeight + itemWeight).toStringAsFixed(2));
        _currentTotalPrice += itemPrice;
        if (!_isReadyToConfirm) {
          _statusMesin = "Item diterima! Masukkan sampah berikutnya atau tekan Konfirmasi di mesin.";
        }
      });
    });

    // Event live perubahan status sesi (WAITING_CONFIRMATION / COMPLETED / CANCELLED)
    socket.on('session:state', (payload) {
      if (!mounted || _hasCompletedNavigation || payload is! Map) return;
      final int? eventSessionId = int.tryParse((payload['sessionId'] ?? '').toString());
      if (eventSessionId != null && eventSessionId != widget.sessionId) return;

      final String status = (payload['status'] ?? '').toString().trim().toUpperCase();
      final dynamic summary = payload['summary'];

      if (status == 'WAITING_CONFIRMATION') {
        HapticFeedback.heavyImpact();
        setState(() {
          _isReadyToConfirm = true;
          _statusMesin = "Mesin selesai menimbang! Silakan konfirmasi di mesin atau aplikasi.";
          if (summary is Map) {
            final w = double.tryParse((summary['currentWeight'] ?? '').toString());
            final p = double.tryParse((summary['totalPrice'] ?? '').toString());
            if (w != null) _currentTotalWeight = w;
            if (p != null) _currentTotalPrice = p;
          }
        });
      } else if (status == 'COMPLETED') {
        // Sesi diselesaikan langsung dari tombol di layar mesin (confirm-by-machine) atau sesi lain
        if (summary is Map) {
          final w = double.tryParse((summary['currentWeight'] ?? '').toString());
          final p = double.tryParse((summary['totalPrice'] ?? '').toString());
          if (w != null) _currentTotalWeight = w;
          if (p != null) _currentTotalPrice = p;
        }
        _navigateToSuccess(
          earned: payload['earned']?.toString(),
          balance: payload['balance']?.toString(),
          pointsEarned: payload['pointsEarned']?.toString(),
          pointsBalance: payload['pointsBalance']?.toString(),
          confirmedBy: payload['confirmedBy']?.toString() ?? 'MACHINE',
        );
      } else if (status == 'CANCELLED') {
        _handleSessionCancelled();
      }
    });

    socket.connect();
    _socket = socket;
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
      _seenItemIds.clear();
      _wasteItems = items.map<WasteItemMap>((item) {
        String typeName = 'Material';
        if (item is Map) {
          final int? itemId = int.tryParse((item['id'] ?? '').toString());
          if (itemId != null) _seenItemIds.add(itemId);

          if (item['wasteType'] is Map) {
            typeName = item['wasteType']['name'] ?? 'Material';
          } else if (item['wasteType'] != null) {
            typeName = item['wasteType'].toString();
          }

          return {
            if (itemId != null) 'id': itemId,
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
        if (!_isReadyToConfirm) HapticFeedback.heavyImpact();
        _isReadyToConfirm = true;
        _statusMesin = "Mesin selesai menimbang! Silakan konfirmasi di mesin atau aplikasi.";
      } else if (status == 'ACTIVE') {
        _statusMesin = _wasteItems.isEmpty
            ? "Pintu mesin terbuka. Masukkan botol/sampah Anda..."
            : "Item diterima! Masukkan sampah berikutnya atau tekan Konfirmasi di mesin.";
      }
    });

    if (status == 'COMPLETED') {
      _navigateToSuccess(
        earned: totalPrice.toStringAsFixed(0),
        confirmedBy: 'MACHINE',
      );
    } else if (status == 'CANCELLED') {
      _handleSessionCancelled();
    }
  }

  Future<void> _syncSessionSnapshot() async {
    if (!mounted || _hasCompletedNavigation) return;
    try {
      var response = await http.get(
        Uri.parse(ApiConfig.getSessionDetail(widget.sessionId.toString())),
        headers: ApiConfig.headers,
      );

      if (response.statusCode != 200) {
        response = await http.get(
          Uri.parse(ApiConfig.getCurrentSession),
          headers: ApiConfig.headers,
        );
      }

      if (response.statusCode == 200 && mounted) {
        final body = jsonDecode(response.body);
        final dynamic data = body['data'];
        if (data is Map) {
          _applySessionData(Map<String, dynamic>.from(data));
        }
      }
    } catch (_) {}
  }

  void _startFallbackSync() {
    _fallbackTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _hasCompletedNavigation) return;
      if (!_isSocketConnected) {
        _syncSessionSnapshot();
      }
    });
  }

  Future<void> _handleConfirm() async {
    if (!_isReadyToConfirm || _hasCompletedNavigation) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.confirmSession(widget.sessionId.toString())),
        headers: ApiConfig.headers,
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final dynamic confirmData = body['data'] ?? {};
        _navigateToSuccess(
          earned: confirmData['earned']?.toString() ?? _currentTotalPrice.toStringAsFixed(0),
          balance: confirmData['balance']?.toString() ?? '0',
          pointsEarned: confirmData['pointsEarned']?.toString() ?? '0',
          pointsBalance: confirmData['pointsBalance']?.toString() ?? '0',
          confirmedBy: 'USER',
        );
      } else if (response.statusCode == 400 || response.statusCode == 409) {
        // Kemungkinan baru saja dikonfirmasi dari layar mesin sepersekian detik sebelumnya
        await _syncSessionSnapshot();
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
          onPressed: () {
            _fallbackTimer?.cancel();
            _disposeSocket();
            Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isSocketConnected ? const Color(0xFFDCFCE7) : Colors.white70,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _isSocketConnected ? ecoGreen : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSocketConnected ? 'LIVE' : 'SYNC',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _isSocketConnected ? ecoGreen : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                  _isReadyToConfirm ? "Konfirmasi & Terima Saldo" : "Menunggu Mesin atau Konfirmasi di Layar Mesin...",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
        ),
      ),
    );
  }
}