import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class KeamananPinPage extends StatefulWidget {
  final String userEmail;
  final bool isEmailVerified;

  const KeamananPinPage({
    super.key,
    required this.userEmail,
    required this.isEmailVerified,
  });

  @override
  State<KeamananPinPage> createState() => _KeamananPinPageState();
}

class _KeamananPinPageState extends State<KeamananPinPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool _isLoadingPin = true;
  bool _isPinSet = false;
  String? _lockedUntil;

  @override
  void initState() {
    super.initState();
    _fetchPinStatus();
  }

  Future<void> _fetchPinStatus() async {
    setState(() => _isLoadingPin = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.userPin),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? {};
        if (mounted) {
          setState(() {
            _isPinSet = data['isSet'] == true;
            _lockedUntil = data['lockedUntil']?.toString();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPin = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : ecoGreen,
        ),
      );
  }

  String _extractError(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['errors'] is List && (body['errors'] as List).isNotEmpty) {
          final first = body['errors'][0];
          if (first is Map && first['msg'] != null) return first['msg'].toString();
        }
        if (body['message'] != null) return body['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  void _openCreatePinDialog() {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Buat PIN Transaksi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PIN 6 digit digunakan untuk mengamankan pencairan saldo dan transaksi dompet.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              _pinField(pinCtrl, 'PIN Baru (6 digit)'),
              const SizedBox(height: 12),
              _pinField(confirmCtrl, 'Ulangi PIN Baru'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark),
              onPressed: submitting
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      final confirm = confirmCtrl.text.trim();
                      if (pin.length != 6 || confirm.length != 6) {
                        _showSnack('PIN harus terdiri dari 6 angka', isError: true);
                        return;
                      }
                      if (pin != confirm) {
                        _showSnack('Konfirmasi PIN tidak cocok', isError: true);
                        return;
                      }
                      setModalState(() => submitting = true);
                      try {
                        final res = await http.post(
                          Uri.parse(ApiConfig.userPin),
                          headers: ApiConfig.headers,
                          body: jsonEncode({'pin': pin, 'confirmPin': confirm}),
                        );
                        if (res.statusCode == 201 || res.statusCode == 200) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack('PIN transaksi berhasil dibuat');
                          _fetchPinStatus();
                        } else {
                          _showSnack(_extractError(res, 'Gagal membuat PIN'), isError: true);
                        }
                      } catch (e) {
                        _showSnack('Kesalahan jaringan: $e', isError: true);
                      } finally {
                        if (ctx.mounted) setModalState(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan PIN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openChangePinDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ubah PIN Transaksi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pinField(oldCtrl, 'PIN Saat Ini (6 digit)'),
              const SizedBox(height: 12),
              _pinField(newCtrl, 'PIN Baru (6 digit)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark),
              onPressed: submitting
                  ? null
                  : () async {
                      final oldPin = oldCtrl.text.trim();
                      final newPin = newCtrl.text.trim();
                      if (oldPin.length != 6 || newPin.length != 6) {
                        _showSnack('PIN lama dan baru harus 6 angka', isError: true);
                        return;
                      }
                      setModalState(() => submitting = true);
                      try {
                        final res = await http.patch(
                          Uri.parse(ApiConfig.userPin),
                          headers: ApiConfig.headers,
                          body: jsonEncode({'currentPin': oldPin, 'newPin': newPin}),
                        );
                        if (res.statusCode == 200) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack('PIN transaksi berhasil diperbarui');
                          _fetchPinStatus();
                        } else {
                          _showSnack(_extractError(res, 'Gagal mengubah PIN'), isError: true);
                        }
                      } catch (e) {
                        _showSnack('Kesalahan jaringan: $e', isError: true);
                      } finally {
                        if (ctx.mounted) setModalState(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Perbarui PIN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForgotPinFlow() async {
    if (!widget.isEmailVerified) {
      _showSnack('Verifikasi email akun Anda terlebih dahulu untuk reset PIN.', isError: true);
      return;
    }

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.forgotUserPin),
        headers: ApiConfig.headers,
      );
      if (res.statusCode != 200) {
        _showSnack(_extractError(res, 'Gagal mengirim kode OTP'), isError: true);
        return;
      }
      _showSnack('Kode OTP 4 digit telah dikirim ke ${widget.userEmail}');
    } catch (e) {
      _showSnack('Kesalahan jaringan: $e', isError: true);
      return;
    }

    if (!mounted) return;
    final codeCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset PIN via Email', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Masukkan 4 digit kode OTP yang dikirim ke ${widget.userEmail} beserta PIN baru.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: InputDecoration(
                  labelText: 'Kode OTP (4 digit)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              _pinField(newPinCtrl, 'PIN Baru (6 digit)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark),
              onPressed: submitting
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim();
                      final newPin = newPinCtrl.text.trim();
                      if (code.length != 4 || newPin.length != 6) {
                        _showSnack('Masukkan 4 digit OTP dan 6 digit PIN baru', isError: true);
                        return;
                      }
                      setModalState(() => submitting = true);
                      try {
                        final res = await http.post(
                          Uri.parse(ApiConfig.resetUserPin),
                          headers: ApiConfig.headers,
                          body: jsonEncode({'code': code, 'newPin': newPin}),
                        );
                        if (res.statusCode == 200) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack('PIN berhasil diatur ulang');
                          _fetchPinStatus();
                        } else {
                          _showSnack(_extractError(res, 'Gagal reset PIN'), isError: true);
                        }
                      } catch (e) {
                        _showSnack('Kesalahan jaringan: $e', isError: true);
                      } finally {
                        if (ctx.mounted) setModalState(() => submitting = false);
                      }
                    },
              child: const Text('Reset PIN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openRemovePinDialog() {
    final passCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nonaktifkan PIN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan kata sandi akun untuk menghapus PIN transaksi.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Akun',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: submitting
                  ? null
                  : () async {
                      if (passCtrl.text.isEmpty) {
                        _showSnack('Kata sandi wajib diisi', isError: true);
                        return;
                      }
                      setModalState(() => submitting = true);
                      try {
                        final res = await http.delete(
                          Uri.parse(ApiConfig.userPin),
                          headers: ApiConfig.headers,
                          body: jsonEncode({'password': passCtrl.text}),
                        );
                        if (res.statusCode == 200) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack('PIN transaksi berhasil dihapus');
                          _fetchPinStatus();
                        } else {
                          _showSnack(_extractError(res, 'Gagal menghapus PIN'), isError: true);
                        }
                      } catch (e) {
                        _showSnack('Kesalahan jaringan: $e', isError: true);
                      } finally {
                        if (ctx.mounted) setModalState(() => submitting = false);
                      }
                    },
              child: const Text('Hapus PIN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ubah Kata Sandi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Lama',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Baru (min. 6 karakter)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Kata Sandi Baru',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark),
              onPressed: submitting
                  ? null
                  : () async {
                      if (currentCtrl.text.isEmpty || newCtrl.text.length < 6) {
                        _showSnack('Kata sandi baru minimal 6 karakter', isError: true);
                        return;
                      }
                      if (newCtrl.text != confirmCtrl.text) {
                        _showSnack('Konfirmasi kata sandi tidak cocok', isError: true);
                        return;
                      }
                      setModalState(() => submitting = true);
                      try {
                        final res = await http.patch(
                          Uri.parse(ApiConfig.changePassword),
                          headers: ApiConfig.headers,
                          body: jsonEncode({
                            'currentPassword': currentCtrl.text,
                            'newPassword': newCtrl.text,
                          }),
                        );
                        if (res.statusCode == 200) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack('Kata sandi berhasil diperbarui');
                        } else {
                          _showSnack(_extractError(res, 'Gagal mengubah kata sandi'), isError: true);
                        }
                      } catch (e) {
                        _showSnack('Kesalahan jaringan: $e', isError: true);
                      } finally {
                        if (ctx.mounted) setModalState(() => submitting = false);
                      }
                    },
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openDeleteAccountDialog() {
    final passCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Hapus Akun Permanen', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tindakan ini akan menonaktifkan akun Anda. Masukkan kata sandi untuk konfirmasi.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Akun',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: submitting
                  ? null
                  : () async {
                      if (passCtrl.text.isEmpty) {
                        _showSnack('Masukkan kata sandi terlebih dahulu', isError: true);
                        return;
                      }
                      setModalState(() => submitting = true);
                      try {
                        final res = await http.delete(
                          Uri.parse(ApiConfig.deleteAccount),
                          headers: ApiConfig.headers,
                          body: jsonEncode({'password': passCtrl.text}),
                        );
                        if (res.statusCode == 200) {
                          ApiConfig.clearToken();
                          if (!mounted) return;
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        } else {
                          _showSnack(_extractError(res, 'Gagal menghapus akun'), isError: true);
                        }
                      } catch (e) {
                        _showSnack('Kesalahan jaringan: $e', isError: true);
                      } finally {
                        if (ctx.mounted) setModalState(() => submitting = false);
                      }
                    },
              child: const Text('Hapus Akun', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: brandYellow,
        elevation: 0,
        title: const Text('Keamanan Akun & PIN', style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.pin_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PIN Transaksi Dompet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                            const SizedBox(height: 2),
                            _isLoadingPin
                                ? const Text('Memeriksa status PIN...', style: TextStyle(fontSize: 12, color: Colors.grey))
                                : Row(
                                    children: [
                                      Icon(
                                        _isPinSet ? Icons.check_circle : Icons.warning_amber_rounded,
                                        size: 14,
                                        color: _isPinSet ? ecoGreen : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isPinSet ? 'PIN 6-Digit Aktif' : 'PIN Belum Diatur',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _isPinSet ? ecoGreen : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_lockedUntil != null && _lockedUntil!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'PIN terkunci sementara hingga $_lockedUntil akibat percobaan salah.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  if (!_isLoadingPin && !_isPinSet)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _openCreatePinDialog,
                        icon: const Icon(Icons.add_moderator_rounded, size: 18),
                        label: const Text('Buat PIN Transaksi (6 Digit)', style: TextStyle(fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandYellow,
                          foregroundColor: textDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (!_isLoadingPin && _isPinSet) ...[
                    _actionRow(
                      icon: Icons.edit_rounded,
                      title: 'Ubah PIN Transaksi',
                      subtitle: 'Ganti PIN 6 digit dengan PIN baru',
                      onTap: _openChangePinDialog,
                    ),
                    const SizedBox(height: 10),
                    _actionRow(
                      icon: Icons.mark_email_read_outlined,
                      title: 'Lupa PIN (Reset via Email)',
                      subtitle: 'Kirim kode OTP ke ${widget.userEmail}',
                      onTap: _openForgotPinFlow,
                    ),
                    const SizedBox(height: 10),
                    _actionRow(
                      icon: Icons.no_encryption_gmailerrorred_rounded,
                      title: 'Nonaktifkan PIN',
                      subtitle: 'Hapus proteksi PIN menggunakan kata sandi',
                      color: const Color(0xFFDC2626),
                      onTap: _openRemovePinDialog,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Akses & Kata Sandi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
                  const SizedBox(height: 14),
                  _actionRow(
                    icon: Icons.lock_reset_rounded,
                    title: 'Ubah Kata Sandi',
                    subtitle: 'Perbarui password masuk akun EcoCash',
                    onTap: _openChangePasswordDialog,
                  ),
                  const SizedBox(height: 10),
                  _actionRow(
                    icon: Icons.person_off_outlined,
                    title: 'Hapus Akun',
                    subtitle: 'Nonaktifkan akun EcoCash secara permanen',
                    color: const Color(0xFFDC2626),
                    onTap: _openDeleteAccountDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = primaryNavy,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color == primaryNavy ? textDark : color)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
