import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic> cartData = {
    'stores': [],
    'summary': {'totalItems': 0, 'totalAmount': 0},
  };
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCart();
  }

  Future<void> fetchCart() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getCart),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          cartData = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  // Fungsi untuk Update Kuantitas
  Future<void> updateQuantity(int itemId, int newQuantity) async {
    await http.patch(
      Uri.parse(ApiConfig.updateCartItem(itemId)),
      headers: ApiConfig.headers,
      body: json.encode({'quantity': newQuantity}),
    );
    fetchCart(); // Refresh data
  }

  // Fungsi untuk Hapus Item
  Future<void> removeItem(int itemId) async {
    await http.delete(
      Uri.parse(ApiConfig.removeCartItem(itemId)),
      headers: ApiConfig.headers,
    );
    fetchCart();
  }

  Future<void> checkout() async {
    final response = await http.post(
      Uri.parse(ApiConfig.checkoutCart),
      headers: ApiConfig.headers,
    );
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Checkout Berhasil!")));
      fetchCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Keranjang Saya"),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: cartData['stores'].length,
              itemBuilder: (context, index) {
                final store = cartData['stores'][index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        store['storeName'],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...List.generate(
                      store['items'].length,
                      (i) => _buildTransactionCard(store['items'][i]),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: _buildCheckoutBar(),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product']['name'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("Rp${item['product']['price']}"),
              ],
            ),
          ),
          // Tombol +/- dan Hapus
          IconButton(
            icon: Icon(Icons.remove_circle_outline),
            onPressed: () => item['quantity'] > 1
                ? updateQuantity(item['id'], item['quantity'] - 1)
                : removeItem(item['id']),
          ),
          Text("${item['quantity']}"),
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () => updateQuantity(item['id'], item['quantity'] + 1),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => removeItem(item['id']),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Total: Rp${cartData['summary']['totalAmount']}",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ElevatedButton(onPressed: checkout, child: Text("Checkout")),
        ],
      ),
    );
  }
}
