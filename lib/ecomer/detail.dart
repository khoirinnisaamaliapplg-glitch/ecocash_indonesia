import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ecocash_indonesia/ecomer/confir.dart';
import 'package:ecocash_indonesia/ipconfig.dart';

class DetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const DetailPage({super.key, required this.product});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _isAddingToCart = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _formatPrice(dynamic rawPrice) {
    if (rawPrice == null) return 'Rp 0';
    final num? priceNum = num.tryParse(rawPrice.toString());
    if (priceNum == null) return 'Rp 0';
    return _currencyFormat.format(priceNum);
  }

  Future<void> _addToCart() async {
    setState(() => _isAddingToCart = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.addCartItem),
        headers: ApiConfig.headers,
        body: json.encode({
          "productId": widget.product['id'],
          "quantity": 1,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil ditambahkan ke keranjang!"),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal menambahkan ke keranjang"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Terjadi kesalahan: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = widget.product['imageUrl'] ?? widget.product['image'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeaderSection(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
              child: _buildProductDetailCard(imageUrl),
            ),
          ),
          _buildBottomActionButtons(context),
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
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Detail Produk',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetailCard(String? imageUrl) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Produk
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 240,
              width: double.infinity,
              color: const Color(0xFFF4F6F8),
              child: (imageUrl != null && imageUrl.startsWith('http'))
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.shopping_cart_outlined, size: 70, color: Colors.grey),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.shopping_cart_outlined, size: 70, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // Nama Produk
          Text(
            widget.product['name'] ?? 'Nama Produk',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),

          // Format Harga Rupiah dengan Pemisah Titik
          Text(
            _formatPrice(widget.product['price']),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E7D32),
            ),
          ),
          const Divider(height: 28),

          // Deskripsi
          const Text(
            "Deskripsi Produk",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product['description'] ?? "Tidak ada deskripsi produk yang tersedia.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isAddingToCart ? null : _addToCart,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xff0BCFD1), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isAddingToCart
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff0BCFD1)),
                        )
                      : const Text(
                          "Keranjang",
                          style: TextStyle(
                            color: Color(0xff0BCFD1),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConfirmationPage(product: widget.product),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Beli Sekarang",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}