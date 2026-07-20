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
  Map? order;
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
        setState(() {
          order = jsonDecode(response.body)['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (order == null)
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Order not found")),
      );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeaderSection(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildOrderDetails(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.only(top: 40, left: 20),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Order #${order!['id']}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Status", style: TextStyle(fontSize: 16)),
              Text(
                order!['status'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          ...List.generate(order!['orderItems'].length, (index) {
            final item = order!['orderItems'][index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${item['product']['name']} x${item['quantity']}"),
                  Text("Rp ${item['subtotal']}"),
                ],
              ),
            );
          }),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Payment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(
                "Rp ${order!['totalAmount']}",
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
