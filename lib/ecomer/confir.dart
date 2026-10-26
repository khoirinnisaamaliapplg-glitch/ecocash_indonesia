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
    final selected = await Navigator.push(
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
          const SnackBar(content: Text("Pesanan berhasil dibuat dengan saldo EcoCash!"), backgroundColor: Colors.green),
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeaderSection(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
              child: Column(
                children: [
                  _buildAddressSection(),
                  const SizedBox(height: 16),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Konfirmasi Pembelian',
                style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                  Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 20),
                  SizedBox(width: 6),
                  Text('Alamat Tujuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              InkWell(
                onTap: _changeAddress,
                child: const Text('Ganti', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 18),
          _isLoadingAddress
              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_addressLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Rincian Pesanan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.product['name'] ?? 'Produk Daur Ulang',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Text("$_quantity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
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
              const Text("Harga Satuan", style: TextStyle(color: Colors.black54, fontSize: 13)),
              Text("Rp ${_rupiah(price)}", style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Metode Pembayaran", style: TextStyle(color: Colors.black54, fontSize: 13)),
              Text("EcoCash Wallet", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 13)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Pembayaran", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                "Rp ${_rupiah(subtotal)}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPayBar(double subtotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _confirmOrder(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    "Bayar Rp ${_rupiah(subtotal)}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}