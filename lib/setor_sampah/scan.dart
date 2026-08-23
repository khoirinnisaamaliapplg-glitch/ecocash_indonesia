import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/konfirmasi.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // ============================================================
  // QR PERMANEN
  // ============================================================

  String? _qrIdentifier;

  bool _isLoading = true;
  String? _errorMessage;

  // ============================================================
  // MACHINE SESSION
  // ============================================================

  Timer? _pollingTimer;

  bool _isCheckingSession = false;
  bool _baselineReady = false;
  bool _hasNavigated = false;

  final Set<String> _knownSessionIds = <String>{};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializePage();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializePage() async {
    debugPrint('');
    debugPrint('======================================');
    debugPrint('SCAN PAGE');
    debugPrint('BASE URL  : ${ApiConfig.baseUrl}');
    debugPrint('HAS TOKEN : ${ApiConfig.hasToken}');
    debugPrint('======================================');
    debugPrint('');

    // Permanent QR membutuhkan user login.
    if (!ApiConfig.hasToken) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = 'Sesi login tidak ditemukan. Silakan login kembali.';
      });

      return;
    }

    // Catat session yang sudah ada sebelum QR dipindai.
    await _prepareSessionBaseline();

    if (!mounted) return;

    // Ambil QR permanent user.
    await _fetchQrCredential();
  }

  // ============================================================
  // GET PERMANENT QR CREDENTIAL
  // ============================================================

  Future<void> _fetchQrCredential() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('');
      debugPrint('========== PERMANENT QR ==========');
      debugPrint('URL    : ${ApiConfig.getMyCredentialQr}');
      debugPrint('TOKEN  : ${ApiConfig.hasToken}');

      final response = await http.get(
        Uri.parse(ApiConfig.getMyCredentialQr),
        headers: ApiConfig.headers,
      );

      debugPrint('STATUS : ${response.statusCode}');

      debugPrint('BODY   : ${response.body}');

      debugPrint('==================================');

      // ========================================================
      // AUTH ERROR
      // ========================================================

      if (response.statusCode == 401) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Sesi login tidak valid. Silakan login kembali.';
        });

        return;
      }

      if (response.statusCode == 403) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Anda tidak memiliki akses untuk mengambil QR.';
        });

        return;
      }

      if (response.statusCode == 404) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Endpoint QR permanen tidak ditemukan.';
        });

        return;
      }

      if (response.statusCode >= 500) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Server gagal mengambil QR EcoCash.';
        });

        return;
      }

      if (response.statusCode != 200) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Gagal memuat QR (${response.statusCode}).';
        });

        return;
      }

      // ========================================================
      // PARSE RESPONSE
      // ========================================================

      final dynamic body = jsonDecode(response.body);

      /*
       * Backend:
       *
       * return success(res, {
       *   message: "...",
       *   data: credential
       * });
       *
       * credential:
       *
       * {
       *   id,
       *   userId,
       *   type,
       *   identifier,
       *   label,
       *   isActive,
       *   lastUsedAt,
       *   createdAt,
       *   updatedAt
       * }
       */

      final dynamic data = body['data'];

      if (data == null || data is! Map) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Data credential QR tidak ditemukan.';
        });

        return;
      }

      // ========================================================
      // INI FIELD YANG BENAR DARI BACKEND
      // ========================================================

      final String? identifier = data['identifier']?.toString().trim();

      debugPrint('QR IDENTIFIER: $identifier');

      if (identifier == null || identifier.isEmpty) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Identifier QR tidak ditemukan.';
        });

        return;
      }

      /*
       * Credential QR harus aktif.
       */
      final bool isActive = data['isActive'] == true;

      if (!isActive) {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'QR EcoCash sedang tidak aktif.';
        });

        return;
      }

      /*
       * Pastikan credential memang QR.
       */
      final String type = data['type']?.toString().toUpperCase() ?? '';

      if (type != 'QR') {
        if (!mounted) return;

        setState(() {
          _qrIdentifier = null;
          _isLoading = false;

          _errorMessage = 'Credential yang diterima bukan QR.';
        });

        return;
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) return;

      setState(() {
        _qrIdentifier = identifier;
        _isLoading = false;
        _errorMessage = null;
      });

      debugPrint('');
      debugPrint('QR PERMANEN BERHASIL DIMUAT');
      debugPrint('IDENTIFIER: $_qrIdentifier');
      debugPrint('');

      // Mulai mendeteksi session baru.
      _startSessionPolling();
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('QR REQUEST ERROR: $e');
      debugPrint('$stackTrace');
      debugPrint('');

      if (!mounted) return;

      setState(() {
        _qrIdentifier = null;
        _isLoading = false;

        _errorMessage = 'Tidak dapat terhubung ke server EcoCash.';
      });
    }
  }

  // ============================================================
  // SESSION BASELINE
  // ============================================================

  Future<void> _prepareSessionBaseline() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMySessionHistory),
        headers: ApiConfig.headers,
      );

      debugPrint('');
      debugPrint('SESSION BASELINE STATUS: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('SESSION BASELINE GAGAL: ${response.body}');

        return;
      }

      final dynamic body = jsonDecode(response.body);

      final List<dynamic> sessions = _extractSessions(body);

      _knownSessionIds.clear();

      for (final dynamic session in sessions) {
        final String? id = _getSessionId(session);

        if (id != null) {
          _knownSessionIds.add(id);
        }
      }

      _baselineReady = true;

      debugPrint('SESSION LAMA: ${_knownSessionIds.length}');
    } catch (e) {
      debugPrint('SESSION BASELINE ERROR: $e');
    }
  }

  // ============================================================
  // START POLLING
  // ============================================================

  void _startSessionPolling() {
    _pollingTimer?.cancel();

    debugPrint('START POLLING MACHINE SESSION');

    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _hasNavigated) {
        return;
      }

      _checkForNewMachineSession();
    });
  }

  // ============================================================
  // CHECK MACHINE SESSION
  // ============================================================

  Future<void> _checkForNewMachineSession({
    bool showMessageIfNotFound = false,
  }) async {
    if (!mounted || _hasNavigated || _isCheckingSession) {
      return;
    }

    _isCheckingSession = true;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMySessionHistory),
        headers: ApiConfig.headers,
      );

      if (response.statusCode != 200) {
        debugPrint(
          'POLLING SESSION ERROR '
          '${response.statusCode}: '
          '${response.body}',
        );

        return;
      }

      final dynamic body = jsonDecode(response.body);

      final List<dynamic> sessions = _extractSessions(body);

      // ========================================================
      // BASELINE BELUM SIAP
      // ========================================================

      if (!_baselineReady) {
        for (final dynamic session in sessions) {
          final String? id = _getSessionId(session);

          if (id != null) {
            _knownSessionIds.add(id);
          }
        }

        _baselineReady = true;

        return;
      }

      // ========================================================
      // FIND NEW SESSION
      // ========================================================

      final List<Map<String, dynamic>> newSessions = [];

      for (final dynamic item in sessions) {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> session = Map<String, dynamic>.from(item);

        final String? id = _getSessionId(session);

        if (id == null) {
          continue;
        }

        if (!_knownSessionIds.contains(id)) {
          newSessions.add(session);
        }
      }

      // Update known session.
      for (final dynamic session in sessions) {
        final String? id = _getSessionId(session);

        if (id != null) {
          _knownSessionIds.add(id);
        }
      }

      // ========================================================
      // BELUM ADA SESSION BARU
      // ========================================================

      if (newSessions.isEmpty) {
        if (showMessageIfNotFound && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mesin belum memindai QR. '
                'Arahkan QR ke scanner mesin EcoCash.',
              ),
            ),
          );
        }

        return;
      }

      // ========================================================
      // FILTER SESSION YANG MASIH AKTIF
      // ========================================================

      final List<Map<String, dynamic>> usableSessions = newSessions.where((
        session,
      ) {
        return _isUsableSession(session);
      }).toList();

      if (usableSessions.isEmpty) {
        return;
      }

      // ========================================================
      // SORT SESSION TERBARU
      // ========================================================

      usableSessions.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final int idA = _parseSessionId(a['id'] ?? a['sessionId']) ?? 0;

        final int idB = _parseSessionId(b['id'] ?? b['sessionId']) ?? 0;

        return idB.compareTo(idA);
      });

      final Map<String, dynamic> newestSession = usableSessions.first;

      final int? sessionId = _parseSessionId(
        newestSession['id'] ?? newestSession['sessionId'],
      );

      if (sessionId == null) {
        return;
      }

      final String status =
          newestSession['status']?.toString().toUpperCase() ?? '';

      debugPrint('');
      debugPrint('======================================');
      debugPrint('MESIN BERHASIL MEMINDAI QR');
      debugPrint('SESSION ID : $sessionId');
      debugPrint('STATUS     : $status');
      debugPrint('======================================');
      debugPrint('');

      _navigateToConfirmation(sessionId);
    } catch (e) {
      debugPrint('CHECK SESSION ERROR: $e');
    } finally {
      _isCheckingSession = false;
    }
  }

  // ============================================================
  // EXTRACT SESSION LIST
  // ============================================================

  List<dynamic> _extractSessions(dynamic responseBody) {
    if (responseBody == null) {
      return [];
    }

    if (responseBody is List) {
      return responseBody;
    }

    if (responseBody is! Map) {
      return [];
    }

    final dynamic data = responseBody['data'];

    // {
    //   "data": [...]
    // }

    if (data is List) {
      return data;
    }

    // {
    //   "data": {
    //      "sessions": [...]
    //   }
    // }

    if (data is Map) {
      final List<dynamic> possibilities = [
        data['sessions'],
        data['items'],
        data['rows'],
        data['results'],
        data['data'],
      ];

      for (final dynamic value in possibilities) {
        if (value is List) {
          return value;
        }
      }
    }

    // Root collection.
    final List<dynamic> possibilities = [
      responseBody['sessions'],
      responseBody['items'],
      responseBody['rows'],
      responseBody['results'],
    ];

    for (final dynamic value in possibilities) {
      if (value is List) {
        return value;
      }
    }

    return [];
  }

  // ============================================================
  // SESSION ID
  // ============================================================

  String? _getSessionId(dynamic session) {
    if (session is! Map) {
      return null;
    }

    final dynamic id = session['id'] ?? session['sessionId'];

    if (id == null) {
      return null;
    }

    final String value = id.toString().trim();

    return value.isEmpty ? null : value;
  }

  int? _parseSessionId(dynamic id) {
    if (id == null) {
      return null;
    }

    if (id is int) {
      return id;
    }

    return int.tryParse(id.toString());
  }

  // ============================================================
  // SESSION STATUS
  // ============================================================

  bool _isUsableSession(Map<String, dynamic> session) {
    final String status = session['status']?.toString().toUpperCase() ?? '';

    const Set<String> terminalStatuses = {
      'COMPLETED',
      'COMPLETE',
      'CANCELLED',
      'CANCELED',
      'EXPIRED',
      'FAILED',
      'REJECTED',
    };

    return !terminalStatuses.contains(status);
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigateToConfirmation(int sessionId) {
    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;

    _pollingTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return SetorSampahScreen(sessionId: sessionId);
        },
      ),
    );
  }

  // ============================================================
  // MANUAL CHECK
  // ============================================================

  Future<void> _manualCheck() async {
    await _checkForNewMachineSession(showMessageIfNotFound: true);
  }

  // ============================================================
  // UI
  // ============================================================

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

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ======================================================
        // HEADER
        // ======================================================
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
                onTap: () {
                  _pollingTimer?.cancel();

                  Navigator.pop(context);
                },
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

        // ======================================================
        // CARD
        // ======================================================
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
                'Arahkan kode QR ini ke scanner mesin,\n'
                'sistem akan otomatis mendeteksi identitas\n'
                'dan memulai sesi transaksi Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),

              const SizedBox(height: 35),

              // ==================================================
              // QR
              // ==================================================
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
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

                  CustomBarcodeFrame(size: 230),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 17,
                    color: Colors.green.shade700,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    'QR EcoCash Permanen',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Kode QR tetap sampai Anda melakukan regenerate.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // BANNER
              // ==================================================
              Image.asset(
                'assets/banner2.jpeg',
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(height: 200);
                },
              ),

              const SizedBox(height: 20),

              // ==================================================
              // RELOAD
              // ==================================================
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fetchQrCredential,
                  icon: const Icon(Icons.refresh, color: Colors.green),
                  label: const Text(
                    'Muat Ulang QR',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ==================================================
              // MANUAL SESSION CHECK
              // ==================================================
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _qrIdentifier == null)
                      ? null
                      : _manualCheck,
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text(
                    'Cek Hasil Scan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isLoading || _qrIdentifier == null)
                        ? Colors.grey
                        : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Halaman akan otomatis berpindah '
                'setelah QR berhasil dipindai mesin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QR CONTENT
  // ============================================================

  Widget _buildQrContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (_qrIdentifier != null && _qrIdentifier!.trim().isNotEmpty) {
      /*
       * PENTING:
       *
       * QR HANYA berisi identifier.
       *
       * Jangan masukkan:
       * - user ID
       * - credential ID
       * - JSON
       * - JWT
       *
       * Karena backend machine memakai:
       *
       * resolveByIdentifier(identifier)
       */

      return Center(
        child: QrImageView(
          data: _qrIdentifier!,
          version: QrVersions.auto,
          size: 180,
          backgroundColor: Colors.white,
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 38),

            const SizedBox(height: 12),

            Text(
              _errorMessage ?? 'Gagal memuat QR EcoCash.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _fetchQrCredential,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// QR FRAME
// ============================================================

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
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double cornerSize = 40;

    // LEFT TOP
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 0)
        ..lineTo(cornerSize, 0),
      paint,
    );

    // RIGHT TOP
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerSize),
      paint,
    );

    // LEFT BOTTOM
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerSize)
        ..lineTo(0, size.height)
        ..lineTo(cornerSize, size.height),
      paint,
    );

    // RIGHT BOTTOM
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
