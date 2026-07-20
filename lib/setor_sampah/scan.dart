import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/konfirmasi.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? _qrToken;       // The access token ID displayed as QR
  bool _isLoading = true;
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _fetchQrToken();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Polls the access-token endpoint to detect when the machine has scanned
  /// the QR code and started a session.
  ///
  /// The backend returns:
  ///   GET /users/access-tokens/{tokenId}
  ///   {
  ///     data: {
  ///       id: "...",
  ///       isUsed: true,
  ///       expiresAt: "...",
  ///       machineSession: { id: 12, status: "ACTIVE" } | null
  ///     }
  ///   }
  ///
  /// When machineSession is not null, the machine has scanned the QR
  /// and started the session → navigate to the confirmation screen.
  Future<void> _checkSessionStatus() async {
    if (_qrToken == null) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSessionStatus(_qrToken!)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200 && mounted) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        final machineSession = data?['machineSession'];

        if (machineSession != null) {
          final int newSessionId = machineSession['id'] as int;
          final String status =
              (machineSession['status']?.toString() ?? '').toUpperCase();

          debugPrint("ScanPage: machine scanned! sessionId=$newSessionId status=$status");

          _timer?.cancel();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SetorSampahScreen(sessionId: newSessionId),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error di ScanPage: $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;

      _checkSessionStatus();

      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _fetchQrToken();
        }
      });
    });
  }

  Future<void> _fetchQrToken() async {
    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isLoading = true;
      _qrToken = null;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMyQr),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // GET /users/me/qr returns { data: { token, expiresAt } }
        String? newToken = responseData['data']?['token']?.toString();

        if (mounted) {
          setState(() {
            _qrToken = newToken;
            _secondsLeft = 30;
            _isLoading = false;
          });
          _startTimer();
        }
      } else {
        throw Exception("Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error Logic: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _secondsLeft = 5;
        });
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(children: [_buildHeader(context)]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              const Text(
                'Setor Sampah',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(
            top: 130,
            left: 20,
            right: 20,
            bottom: 20,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tunjukkan Kode QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Arahkan kode QR ini ke scanner mesin,\nAI akan otomatis mendeteksi identitas\ndan memulai sesi transaksi Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 35),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.green,
                              ),
                            )
                          : (_qrToken != null
                                ? Center(
                                    child: QrImageView(
                                      data: _qrToken!,
                                      version: QrVersions.auto,
                                      size: 180.0,
                                    ),
                                  )
                                : const Center(child: Text("Gagal memuat QR"))),
                    ),
                  ),
                  CustomBarcodeFrame(size: 230),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Berubah dalam $_secondsLeft detik",
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Image.asset(
                'banner2.jpeg',
                height: 200,
                errorBuilder: (c, e, s) => const SizedBox(height: 200),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _fetchQrToken,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Refresh Kode",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // TOMBOL KONFIRMASI MANUAL (fallback if auto-navigate doesn't work)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _qrToken == null)
                      ? null
                      : () async {
                          // Try to get session ID from the access token
                          try {
                            final response = await http.get(
                              Uri.parse(ApiConfig.getSessionStatus(_qrToken!)),
                              headers: ApiConfig.headers,
                            );
                            if (response.statusCode == 200 && mounted) {
                              final body = jsonDecode(response.body);
                              final machineSession =
                                  body['data']?['machineSession'];
                              if (machineSession != null) {
                                final int sid =
                                    machineSession['id'] as int;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SetorSampahScreen(sessionId: sid),
                                  ),
                                );
                                return;
                              }
                            }
                          } catch (_) {}
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Mesin belum memindai QR. Arahkan QR ke scanner mesin."),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isLoading || _qrToken == null)
                        ? Colors.grey
                        : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Lanjut ke Konfirmasi",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    final paint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    double cornerSize = 40;
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 0)
        ..lineTo(cornerSize, 0),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerSize),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerSize)
        ..lineTo(0, size.height)
        ..lineTo(cornerSize, size.height),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
