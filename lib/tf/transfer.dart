import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../ipconfig.dart';

// Alias tipe agar kebal error copy-paste kurung siku generik
typedef WalletDataMap = Map<String, dynamic>;

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  // Palet Warna Gojek-Inspired EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color brandYellowDark = Color(0xFFF5D000);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  static const double adminFee = 2500.0;

  bool _isLoadingWallet = true;
  bool _isSubmitting = false;
  double _balance = 0.0;

  String _selectedMethodType = 'BANK';
  String _selectedProvider = 'BCA';

  final List<String> _bankOptions = ['BCA', 'BRI', 'Mandiri', 'BNI'];
  final List<String> _ewalletOptions = ['GoPay', 'DANA', 'OVO', 'ShopeePay'];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletBalance() async {
    setState(() => _isLoadingWallet = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getMyWallet),
        headers: ApiConfig.headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? decoded;
        final rawBalance = data['balance'] ?? 0;

        setState(() {
          _balance = (rawBalance is num)
              ? rawBalance.toDouble()
              : double.tryParse(rawBalance.toString()) ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat saldo: $e");
    } finally {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    FocusScope.of(context).unfocus();

    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double? amount = double.tryParse(rawAmount);

    if (amount == null || amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimal penarikan saldo adalah Rp 10.000"), backgroundColor: Colors.orange),
      );
      return;
    }

    final double totalRequired = amount + adminFee;
    if (_balance < totalRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saldo tidak cukup. Dibutuhkan ${_currencyFormat.format(totalRequired)} (Termasuk admin Rp 2.500)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedMethodType == 'BANK' ? "Nomor rekening wajib diisi" : "Nomor e-wallet/HP wajib diisi"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountHolderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama pemilik rekening/akun wajib diisi"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        "amount": amount,
        "bankName": _selectedProvider,
        "accountNumber": _accountNumberController.text.trim(),
        "accountHolderName": _accountHolderController.text.trim(),
      };

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/wallets/withdraw"),
        headers: ApiConfig.headers,
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: ecoGreen, size: 28),
                SizedBox(width: 10),
                Text("Penarikan Berhasil!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark)),
              ],
            ),
            content: Text(
              "Pencairan dana ${_currencyFormat.format(amount)} ke $_selectedProvider (${_accountNumberController.text.trim()}) sedang diproses.\n\nBiaya Admin: Rp 2.500\nSisa Saldo: ${_currencyFormat.format(data['data']?['balanceAfter'] ?? (_balance - totalRequired))}",
              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  foregroundColor: textDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _amountController.clear();
                  _accountNumberController.clear();
                  _accountHolderController.clear();
                  _fetchWalletBalance();
                },
                child: const Text("Selesai", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Penarikan saldo gagal'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kesalahan jaringan: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showTransactionHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) {
              return FutureBuilder<http.Response>(
                future: http.get(Uri.parse(ApiConfig.getMyWalletTransactions), headers: ApiConfig.headers),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryNavy));
                  }

                  if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
                    return const Center(child: Text("Gagal memuat mutasi dompet"));
                  }

                  final decoded = jsonDecode(snapshot.data!.body);
                  final List items = decoded['data'] is List ? decoded['data'] : [];

                  if (items.isEmpty) {
                    return const Center(child: Text("Belum ada riwayat transaksi", style: TextStyle(color: Colors.grey)));
                  }

                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: brandYellow.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: textDark, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text("Mutasi Saldo Dompet", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textDark)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final tx = items[i];
                            final isDeposit = tx['type'] == 'DEPOSIT';
                            final double amt = (tx['amount'] is num) ? (tx['amount'] as num).toDouble() : 0.0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: isDeposit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                child: Icon(
                                  isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: isDeposit ? ecoGreen : const Color(0xFFDC2626),
                                  size: 18,
                                ),
                              ),
                              title: Text(tx['description'] ?? 'Transaksi Dompet', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                              subtitle: Text(
                                tx['createdAt'] != null ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(tx['createdAt']).toLocal()) : '-',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: Text(
                                "${isDeposit ? '+' : '-'}${_currencyFormat.format(amt)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isDeposit ? ecoGreen : const Color(0xFFDC2626),
                                  fontSize: 13,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 70),
            _buildWithdrawalForm(),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFEA2E),
                brandYellow,
                Color(0xFFFFDF00),
              ],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: textDark),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Pencairan Dana',
                      style: TextStyle(color: textDark, fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showTransactionHistoryDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: textDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.history_rounded, color: brandYellow, size: 16),
                      SizedBox(width: 6),
                      Text('Mutasi', style: TextStyle(color: brandYellow, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(top: 130, left: 18, right: 18, child: _buildBalanceCard()),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A000).withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saldo yang Bisa Dicairkan', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Tersedia', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _isLoadingWallet
              ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(color: primaryNavy, strokeWidth: 2))
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: brandYellow.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: textDark, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _currencyFormat.format(_balance),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Biaya transfer antar-rekening flat Rp 2.500 per transaksi.",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalForm() {
    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double enteredAmount = double.tryParse(rawAmount) ?? 0.0;
    final double totalEstimatedDeduction = enteredAmount > 0 ? enteredAmount + adminFee : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Metode Pencairan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTypeSelector('BANK', 'Transfer Bank', Icons.account_balance_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeSelector('EWALLET', 'E-Wallet', Icons.phone_android_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Pilih Penyedia:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_selectedMethodType == 'BANK' ? _bankOptions : _ewalletOptions).map((prov) {
              final isSelected = _selectedProvider == prov;
              return ChoiceChip(
                label: Text(prov, style: TextStyle(color: textDark, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600)),
                selected: isSelected,
                selectedColor: brandYellow,
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: isSelected ? textDark : Colors.transparent),
                onSelected: (val) {
                  if (val) setState(() => _selectedProvider = prov);
                },
              );
            }).toList(),
          ),
          const Divider(height: 28),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _selectedMethodType == 'BANK' ? 'Nomor Rekening' : 'Nomor Handphone E-Wallet',
              hintText: _selectedMethodType == 'BANK' ? 'Contoh: 1234567890' : 'Contoh: 081234567890',
              filled: true,
              fillColor: surfaceBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: textDark, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountHolderController,
            decoration: InputDecoration(
              labelText: 'Nama Pemilik Rekening / Akun',
              hintText: 'Sesuai buku tabungan / KTP',
              filled: true,
              fillColor: surfaceBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: textDark, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 16),
              labelText: 'Nominal Penarikan',
              hintText: 'Minimal 10.000',
              filled: true,
              fillColor: surfaceBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: textDark, width: 1.5)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Minimal Rp 10.000', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              InkWell(
                onTap: () {
                  final double maxWithdrawable = _balance - adminFee;
                  if (maxWithdrawable >= 10000) {
                    setState(() {
                      _amountController.text = maxWithdrawable.toInt().toString();
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Saldo tidak cukup setelah dipotong admin Rp 2.500"), backgroundColor: Colors.orange),
                    );
                  }
                },
                child: const Text('Tarik Maksimal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textDark)),
              ),
            ],
          ),
          if (enteredAmount > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Saldo Terpotong (+Admin):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _currencyFormat.format(totalEstimatedDeduction),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: totalEstimatedDeduction <= _balance ? textDark : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSelector(String type, String label, IconData icon) {
    final bool active = _selectedMethodType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethodType = type;
          _selectedProvider = type == 'BANK' ? _bankOptions.first : _ewalletOptions.first;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? brandYellow.withOpacity(0.3) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? textDark : Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textDark),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double amount = double.tryParse(rawAmount) ?? 0;
    final double totalRequired = amount + adminFee;
    final bool valid = amount >= 10000 && totalRequired <= _balance && !_isSubmitting;

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: valid ? _submitWithdrawal : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandYellow,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              foregroundColor: textDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: textDark, strokeWidth: 2))
                : Text(
                    valid ? "Tarik ${_currencyFormat.format(amount)}" : "Masukkan Nominal Valid",
                    style: TextStyle(
                      color: valid ? textDark : Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}