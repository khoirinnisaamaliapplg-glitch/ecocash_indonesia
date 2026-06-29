import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/setor_sampah/transaksi.dart';

class SetorSampahScreen extends StatefulWidget {
  final String? sessionId;

  const SetorSampahScreen({super.key, this.sessionId});

  @override
  State<SetorSampahScreen> createState() => _SetorSampahScreenState();
}

class _SetorSampahScreenState extends State<SetorSampahScreen> {
  bool _isLoading = false;
  bool _isReadyToConfirm = false;
  String _statusMesin = "Menunggu mesin selesai menimbang...";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
  _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSessionDetail(widget.sessionId!)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("Status dari server: ${data['status']}");

        // Ganti 'completed' menjadi 'WAITING_CONFIRMATION'
        if (data['status'] == 'WAITING_CONFIRMATION') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _statusMesin = "Selesai! Silakan konfirmasi.";
              _isReadyToConfirm = true;
            });
          }
        } 
        // Tambahan: Tangani jika sesi dibatalkan oleh mesin
        else if (data['status'] == 'CANCELLED') {
           timer.cancel();
           // Tampilkan pesan error atau kembali ke halaman sebelumnya
           _showSnackBar("Sesi dibatalkan oleh mesin", Colors.red);
        }
      }
    } catch (e) {
      debugPrint("Error saat polling: $e");
    }
  });
}

  Future<void> _handleConfirm() async {
    if (!_isReadyToConfirm) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.confirmSession(widget.sessionId!)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TransaksiBerhasilScreen(detailTransaksi: responseData),
            ),
            (route) => route.isFirst,
          );
        }
      } else {
        _showSnackBar(
          "Gagal konfirmasi: ${jsonDecode(response.body)['message']}",
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar("Koneksi terputus.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
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
                  top: 150,
                  left: 20,
                  right: 20,
                  child: _buildScanResultCard(),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFF4CAF50)),
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
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
    );
  }

  Widget _buildScanResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text(
            'Status Transaksi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (!_isReadyToConfirm) const CircularProgressIndicator(),
          const SizedBox(height: 15),
          Text(
            _statusMesin,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isReadyToConfirm ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: ElevatedButton(
        onPressed: (_isReadyToConfirm && !_isLoading) ? _handleConfirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF388E3C),
          minimumSize: const Size(double.infinity, 55),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _isReadyToConfirm ? 'Konfirmasi SDU' : 'Menunggu Selesai...',
                style: const TextStyle(color: Colors.white),
              ),
      ),
    );
  }
}
