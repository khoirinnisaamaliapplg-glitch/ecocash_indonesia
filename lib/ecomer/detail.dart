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
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

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
            backgroundColor: ecoGreen,
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
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          _buildHeaderSection(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _buildProductDetailCard(imageUrl),
            ),
          ),
          _buildBottomActionButtons(context),
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
                'Detail Produk',
                style: TextStyle(
                  color: textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetailCard(String? imageUrl) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 240,
              width: double.infinity,
              color: surfaceBg,
              child: (imageUrl != null && imageUrl.startsWith('http'))
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.shopping_bag_outlined, size: 70, color: Colors.grey),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.shopping_bag_outlined, size: 70, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.product['name'] ?? 'Nama Produk',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPrice(widget.product['price']),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: ecoGreen,
            ),
          ),
          const Divider(height: 28),
          const Text(
            "Deskripsi Produk",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _isAddingToCart ? null : _addToCart,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: textDark, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isAddingToCart
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: textDark),
                        )
                      : const Text(
                          "+ Keranjang",
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
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
                    backgroundColor: brandYellow,
                    foregroundColor: textDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "Beli Sekarang",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
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