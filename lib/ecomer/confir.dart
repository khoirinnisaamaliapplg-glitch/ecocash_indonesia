import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ecocash_indonesia/ecomer/OrdersPage.dart';
import 'package:ecocash_indonesia/ipconfig.dart'; // Sesuaikan path ini

class ConfirmationPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const ConfirmationPage({super.key, required this.product});

  // Fungsi untuk memproses API
  Future<void> _confirmOrder(BuildContext context) async {
    try {
      // Pastikan productId diubah menjadi int sebelum dikirim
      final int pId = int.tryParse(product['id'].toString()) ?? 0;

      if (pId == 0) {
        throw Exception("Invalid Product ID");
      }

      final response = await http.post(
        Uri.parse(ApiConfig.createOrder),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'items': [
            {
              'productId': pId, // Kirim sebagai integer, bukan string
              'quantity': 1,
            },
          ],
          'notes': 'Order via mobile app',
        }),
      );

      // Tambahkan log untuk debugging jika error
      // Di dalam ConfirmationPage, pada fungsi _confirmOrder
      if (response.statusCode == 201) {
        if (!context.mounted) return;

        // Ganti Navigator.pop(context) dengan ini:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OrdersPage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order created successfully!")),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeaderSection(context),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => _confirmOrder(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Pay Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          padding: const EdgeInsets.only(top: 60, left: 20),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
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
                const SizedBox(width: 12),
                const Text(
                  'Confirm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(top: 120, left: 15, right: 15, child: _buildSummaryCard()),
      ],
    );
  }

  Widget _buildSummaryCard() {
    // Menghitung subtotal secara sederhana
    final price = double.tryParse(product['price'].toString()) ?? 0.0;
    final quantity = 1; // Jika ada state quantity, gunakan itu
    final subtotal = price * quantity;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Order Summary",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(product['name'] ?? 'Product'),
              Text(
                "Qty: $quantity",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Price per item"),
              Text("Rp ${product['price']}"),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Payment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(
                "Rp $subtotal",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
