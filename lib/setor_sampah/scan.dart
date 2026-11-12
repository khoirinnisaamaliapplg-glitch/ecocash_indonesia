import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/konfirmasi.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);

  String? _qrIdentifier;
  bool _isLoading = true;
  bool _isRegenerating = false;
  bool _isSocketConnected = false;

  IO.Socket? _socket;
  Timer? _fallbackTimer;
  bool _isCheckingSession = false;
  bool _hasNavigated = false;
  int _secondsWaiting = 0;
  final int _maxWaitSeconds = 45;

  @override
  void initState() {
    super.initState();
    _initializePage();
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
      _socket!.off('session:started');
      _socket!.off('session:state');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  Future<void> _initializePage() async {
    if (!ApiConfig.hasToken) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }
    _initSessionSocket();
    await _fetchQrCredential();
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
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() => _isSocketConnected = false);
    });

    // Event real-time saat mesin selesai memindai QR user
    socket.on('session:started', (payload) async {
      if (!mounted || _hasNavigated) return;
      final map = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
      final int? sessionId = int.tryParse((map['sessionId'] ?? map['id'] ?? '').toString());
      if (sessionId != null) {
        await _fetchAndNavigateToSession(sessionId);
      } else {
        await _checkForOpenSession();
      }
    });

    // Jika user sudah memiliki sesi WAITING_CONFIRMATION yang terbuka
    socket.on('session:state', (payload) async {
      if (!mounted || _hasNavigated) return;
      final map = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
      final status = (map['status'] ?? '').toString().toUpperCase();
      final int? sessionId = int.tryParse((map['sessionId'] ?? map['id'] ?? '').toString());
      if ((status == 'ACTIVE' || status == 'WAITING_CONFIRMATION') && sessionId != null) {
        await _fetchAndNavigateToSession(sessionId);
      }
    });

    socket.connect();
    _socket = socket;
  }

  Future<void> _fetchAndNavigateToSession(int sessionId) async {
    if (!mounted || _hasNavigated) return;
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSessionDetail(sessionId.toString())),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final dynamic data = body['data'];
        if (data is Map) {
          _navigateToSessionDetail(sessionId, Map<String, dynamic>.from(data));
          return;
        }
      }
    } catch (_) {}
    _navigateToSessionDetail(sessionId, {'id': sessionId, 'status': 'ACTIVE'});
  }

  Future<void> _fetchQrCredential() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMyCredentialQr),
        headers: ApiConfig.headers,
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final body = jsonDecode(response.body);
      final data = body['data'];
      final String? identifier = data?['identifier']?.toString().trim();

      if (identifier == null || identifier.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _qrIdentifier = identifier;
        _isLoading = false;
        _secondsWaiting = 0;
      });

      // Cek langsung sekali jika sesi ternyata sudah aktif, lalu pasang fallback interval lambat
      await _checkForOpenSession();
      _startFallbackSync();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _regenerateQrCredential() async {
    setState(() => _isRegenerating = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.regenerateMyCredentialQr),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final newIdentifier = body['data']?['identifier']?.toString().trim();

        if (newIdentifier != null && newIdentifier.isNotEmpty && mounted) {
          setState(() {
            _qrIdentifier = newIdentifier;
            _secondsWaiting = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kode QR berhasil diperbarui!'),
              backgroundColor: Color(0xFF00AA13),
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  void _startFallbackSync() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _hasNavigated) return;
      _secondsWaiting += 6;
      if (!_isSocketConnected) {
        _checkForOpenSession();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _checkForOpenSession({bool isManualCheck = false}) async {
    if (!mounted || _hasNavigated || _isCheckingSession) return;
    _isCheckingSession = true;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getCurrentSession),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final dynamic sessionData = body['data'];

        if (sessionData != null && sessionData is Map && sessionData['id'] != null) {
          final int sessionId = int.parse(sessionData['id'].toString());
          final String status = (sessionData['status'] ?? '').toString().toUpperCase();

          if (status == 'ACTIVE' || status == 'WAITING_CONFIRMATION') {
            _navigateToSessionDetail(sessionId, Map<String, dynamic>.from(sessionData));
            return;
          }
        }
      }

      if (isManualCheck && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesin belum memindai QR. Arahkan layar ke kamera scanner mesin.')),
        );
      }
    } catch (_) {
    } finally {
      _isCheckingSession = false;
    }
  }

  void _navigateToSessionDetail(int sessionId, Map<String, dynamic> initialSessionData) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _fallbackTimer?.cancel();
    _disposeSocket();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SetorSampahScreen(
          sessionId: sessionId,
          initialSessionData: initialSessionData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTimeout = _secondsWaiting >= _maxWaitSeconds && !_hasNavigated;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        child: Column(children: [_buildHeader(context, isTimeout)]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTimeout) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: brandYellow,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () {
                  _fallbackTimer?.cancel();
                  _disposeSocket();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back, color: textDark),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Setor ke Smart Container',
                  style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 120, left: 18, right: 18, bottom: 20),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tunjukkan QR ke Mesin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark)),
              const SizedBox(height: 6),
              const Text(
                'Dekatkan kode QR ke kamera Smart Container untuk membuka pintu pembuangan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _buildQrContent(),
                    ),
                  ),
                  const CustomBarcodeFrame(size: 220),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSocketConnected ? Icons.wifi_tethering_rounded : Icons.verified,
                    size: 16,
                    color: const Color(0xFF00AA13),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSocketConnected ? 'Terhubung Live • QR Warga Aktif' : 'QR Identitas Warga Aktif',
                    style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isTimeout)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Belum terdeteksi? Pastikan layar terang dan posisikan QR tepat di depan kamera mesin.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isLoading || _isRegenerating) ? null : _regenerateQrCredential,
                  icon: const Icon(Icons.refresh, color: textDark),
                  label: const Text('Perbarui QR', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: textDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _qrIdentifier == null) ? null : () => _checkForOpenSession(isManualCheck: true),
                  icon: const Icon(Icons.qr_code_scanner, color: textDark),
                  label: const Text('Cek Sambungan Mesin', style: TextStyle(color: textDark, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandYellow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryNavy));
    }

    if (_qrIdentifier != null && _qrIdentifier!.trim().isNotEmpty) {
      return Center(
        child: QrImageView(
          data: _qrIdentifier!,
          version: QrVersions.auto,
          size: 170,
          backgroundColor: Colors.white,
        ),
      );
    }

    return Center(
      child: TextButton(
        onPressed: _fetchQrCredential,
        child: const Text('Muat Ulang QR'),
      ),
    );
  }
}

class CustomBarcodeFrame extends StatelessWidget {
  final double size;
  const CustomBarcodeFrame({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: BarcodeFramePainter()),
    );
  }
}

class BarcodeFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double corner = 32;
    canvas.drawPath(Path()..moveTo(0, corner)..lineTo(0, 0)..lineTo(corner, 0), paint);
    canvas.drawPath(Path()..moveTo(size.width - corner, 0)..lineTo(size.width, 0)..lineTo(size.width, corner), paint);
    canvas.drawPath(Path()..moveTo(0, size.height - corner)..lineTo(0, size.height)..lineTo(corner, size.height), paint);
    canvas.drawPath(Path()..moveTo(size.width - corner, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - corner), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}