import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';

class OrderDetailPage extends StatefulWidget {
  final int orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  Map<String, dynamic>? order;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getOrderById(widget.orderId.toString())),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          order = decoded['data'] is Map ? Map<String, dynamic>.from(decoded['data']) : null;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _rupiah(dynamic value) {
    if (value == null) return '0';
    final n = num.tryParse(value.toString()) ?? 0;
    return n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(backgroundColor: surfaceBg, body: Center(child: CircularProgressIndicator(color: textDark)));
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: brandYellow, leading: IconButton(icon: const Icon(Icons.arrow_back, color: textDark), onPressed: () => Navigator.pop(context))),
        body: const Center(child: Text("Detail pesanan tidak ditemukan")),
      );
    }

    return Scaffold(
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          _buildHeaderSection(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _buildOrderDetails(),
            ),
          ),
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
                icon: const Icon(Icons.arrow_back, color: textDark),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text(
                'Pesanan #${order!['id']}',
                style: const TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    final List items = order!['orderItems'] is List ? order!['orderItems'] : [];
    final String status = (order!['status'] ?? 'PENDING').toString().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Status Pesanan", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'COMPLETED' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: status == 'COMPLETED' ? ecoGreen : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text("Daftar Item", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textDark)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text("Tidak ada rincian item", style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...items.map((item) {
              final product = item['product'] is Map ? item['product'] : {};
              final name = product['name']?.toString() ?? 'Produk';
              final qty = item['quantity']?.toString() ?? '1';

              // Menggunakan Expanded agar bebas dari RenderFlex Overflow
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "$name  x$qty",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Rp ${_rupiah(item['subtotal'])}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textDark),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Pembayaran", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark)),
              Text(
                "Rp ${_rupiah(order!['totalAmount'])}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ecoGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}