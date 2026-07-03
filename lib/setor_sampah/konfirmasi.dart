import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk HapticFeedback
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/transaksi.dart';

class SetorSampahScreen extends StatefulWidget {
  final int? sessionId;

  const SetorSampahScreen({super.key, this.sessionId});

  @override
  State<SetorSampahScreen> createState() => _SetorSampahScreenState();
}

class _SetorSampahScreenState extends State<SetorSampahScreen> {
  bool _isLoading = false;
  bool _isReadyToConfirm = false;
  String _statusMesin = "Menunggu mesin selesai menimbang...";
  Timer? _timer;

  // Timeout setelah 5 menit agar tidak terus-menerus polling
  int _secondsElapsed = 0;
  final int _maxSeconds = 300;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      _startPolling();
    } else {
      _statusMesin = "ID Sesi tidak ditemukan.";
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _secondsElapsed += 2;

      if (!mounted || _secondsElapsed >= _maxSeconds) {
        timer.cancel();
        if (mounted && !_isReadyToConfirm) {
          setState(
            () => _statusMesin = "Waktu tunggu habis. Silakan scan ulang.",
          );
        }
        return;
      }

      try {
        // PENTING: Pastikan parameter adalah int, ApiConfig akan menghandle konversi ke string URL
        final response = await http.get(
          Uri.parse(ApiConfig.getSessionDetail(widget.sessionId!.toString())),
          headers: ApiConfig.headers,
        );

        if (response.statusCode == 200 && mounted) {
          final data = jsonDecode(response.body);
          // Sesuaikan dengan struktur response detail session Anda
          String status = data['status']?.toString().trim().toUpperCase() ?? "";

          if (status == 'WAITING_CONFIRMATION') {
            timer.cancel();
            HapticFeedback.heavyImpact();
            setState(() {
              _statusMesin = "Selesai! Silakan konfirmasi untuk proses data.";
              _isReadyToConfirm = true;
            });
          } else if (status == 'CANCELLED' || status == 'FAILED') {
            timer.cancel();
            setState(() => _statusMesin = "Transaksi gagal/dibatalkan.");
          }
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  Future<void> _handleConfirm() async {
    if (!_isReadyToConfirm || widget.sessionId == null) return;

    setState(() => _isLoading = true);

    try {
      // Pastikan fungsi confirmSession di ApiConfig menerima int
      final response = await http.post(
        Uri.parse(ApiConfig.confirmSession(widget.sessionId!.toString())),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200 && mounted) {
        final responseData = jsonDecode(response.body);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TransaksiBerhasilScreen(detailTransaksi: responseData),
          ),
          (route) => route.isFirst,
        );
      } else {
        _showSnackBar("Gagal konfirmasi: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Koneksi bermasalah: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) => _timer?.cancel(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4CAF50),
          title: const Text(
            'Setor Sampah',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    if (!_isReadyToConfirm) ...[
                      const CircularProgressIndicator(color: Color(0xFF4CAF50)),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      _statusMesin,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isReadyToConfirm
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            onPressed: (_isReadyToConfirm && !_isLoading)
                ? _handleConfirm
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "Konfirmasi Transaksi",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }
}
