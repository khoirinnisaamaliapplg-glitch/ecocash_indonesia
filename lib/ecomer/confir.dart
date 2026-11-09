import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ecomer/OrdersPage.dart';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/profile/daftar_alamat_page.dart';

class ConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ConfirmationPage({super.key, required this.product});

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  int _quantity = 1;
  bool _isLoading = false;
  bool _isLoadingAddress = true;

  int? _selectedAddressId;
  String _addressLabel = 'Memuat alamat pengiriman...';
  String _addressDetail = '';

  @override
  void initState() {
    super.initState();
    _fetchDefaultAddress();
  }

  Future<void> _fetchDefaultAddress() async {
    setState(() => _isLoadingAddress = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getUserAddresses),
        headers: ApiConfig.headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List list = decoded['data'] ?? [];
        if (list.isNotEmpty) {
          final defaultAddr = list.firstWhere(
            (a) => a['isDefault'] == true,
            orElse: () => list.first,
          );
          setState(() {
            _selectedAddressId = defaultAddr['id'];
            _addressLabel = defaultAddr['label'] ?? 'Alamat Utama';
            _addressDetail = defaultAddr['detail'] ?? defaultAddr['address'] ?? '';
          });
        } else {
          setState(() {
            _addressLabel = 'Belum Ada Alamat';
            _addressDetail = 'Silakan pilih atau tambahkan alamat pengiriman.';
          });
        }
      }
    } catch (_) {
      setState(() {
        _addressLabel = 'Alamat Pengiriman';
        _addressDetail = 'Gagal memuat alamat secara otomatis.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _changeAddress() async {
    final dynamic selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DaftarAlamatPage(isSelecting: true),
      ),
    );

    if (selected != null && selected is Map) {
      setState(() {
        _selectedAddressId = selected['id'];
        _addressLabel = selected['label'] ?? 'Alamat Terpilih';
        _addressDetail = selected['detail'] ?? selected['address'] ?? '';
      });
    }
  }

  Future<void> _confirmOrder(BuildContext context) async {
    final int pId = int.tryParse(widget.product['id'].toString()) ?? 0;
    if (pId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID Produk tidak valid"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih alamat pengiriman terlebih dahulu"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'items': [
          {
            'productId': pId,
            'quantity': _quantity,
          },
        ],
        'paymentMethod': 'WALLET',
        'addressId': _selectedAddressId,
        'notes': 'Order instan via aplikasi mobile',
      };

      final response = await http.post(
        Uri.parse(ApiConfig.createOrder),
        headers: ApiConfig.headers,
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OrdersPage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pesanan berhasil dibuat dengan saldo EcoCash!"), backgroundColor: ecoGreen),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Gagal memproses pesanan"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _rupiah(num value) {
    final raw = value.round().toString();
    return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(widget.product['price'].toString()) ?? 0.0;
    final subtotal = price * _quantity;

    return Scaffold(
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          _buildHeaderSection(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildAddressSection(),
                  const SizedBox(height: 14),
                  _buildSummaryCard(price, subtotal),
                ],
              ),
            ),
          ),
          _buildBottomPayBar(subtotal),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: textDark),
              ),
              const SizedBox(width: 8),
              const Text(
                'Konfirmasi Pembelian',
                style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.location_on_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 8),
                  Text('Alamat Tujuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                ],
              ),
              InkWell(
                onTap: _changeAddress,
                child: const Text('Ganti', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 18),
          _isLoadingAddress
              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: textDark)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_addressLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                    const SizedBox(height: 3),
                    Text(_addressDetail, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double price, double subtotal) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Rincian Pesanan", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.product['name'] ?? 'Produk Daur Ulang',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20, color: textDark),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Text("$_quantity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: textDark),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Harga Satuan", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              Text("Rp ${_rupiah(price)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Metode Pembayaran", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              Text("EcoCash Wallet", style: TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 13)),
            ],
          ),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Pembayaran", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
              Text(
                "Rp ${_rupiah(subtotal)}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ecoGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPayBar(double subtotal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _confirmOrder(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandYellow,
              foregroundColor: textDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: textDark, strokeWidth: 2))
                : Text(
                    "Bayar Rp ${_rupiah(subtotal)}",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
      ),
    );
  }
}