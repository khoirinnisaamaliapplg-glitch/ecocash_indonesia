import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ecocash_indonesia/ecomer/cart.dart';
import 'package:ecocash_indonesia/ecomer/OrdersPage.dart';
import 'detail.dart';
import 'package:ecocash_indonesia/ipconfig.dart';

class EcomerPage extends StatefulWidget {
  const EcomerPage({super.key});

  @override
  State<EcomerPage> createState() => _EcomerPageState();
}

class _EcomerPageState extends State<EcomerPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  late Future<List<dynamic>> _productsFuture;
  int _cartItemCount = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
    _fetchCartCount();
  }

  // ============================================================
  // AMBIL TOTAL ITEM KERANJANG AKTIF DARI BACKEND
  // ============================================================
  Future<void> _fetchCartCount() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getCart),
        headers: ApiConfig.headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        int total = 0;
        dynamic data = decoded;
        if (decoded is Map) {
          data = decoded['data'] ?? decoded;
        }

        if (data is Map) {
          if (data['summary'] != null && data['summary']['totalItems'] != null) {
            total = int.tryParse(data['summary']['totalItems'].toString()) ?? 0;
          } else if (data['stores'] is List) {
            for (var store in data['stores']) {
              if (store is Map && store['items'] is List) {
                for (var item in store['items']) {
                  total += int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _cartItemCount = total;
          });
        }
      }
    } catch (_) {}
  }

  Future<List<dynamic>> _fetchProducts() async {
    final response = await http.get(
      Uri.parse(ApiConfig.getProducts),
      headers: ApiConfig.headers,
    );

    if (response.statusCode == 200) {
      final decodedData = json.decode(response.body);
      if (decodedData is Map && decodedData.containsKey('data')) {
        return decodedData['data'];
      } else if (decodedData is List) {
        return decodedData;
      }
      return [];
    } else {
      throw Exception('Gagal memuat produk: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          SizedBox(
            height: 330,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildHeaderSection(context),
                Positioned(
                  top: 130,
                  left: 18,
                  right: 18,
                  child: _buildBannerCard(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildMainContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: textDark),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'EcoMart Daur Ulang',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              // Ikon Keranjang dengan Badge Counter Real-time
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CartScreen()),
                    ).then((_) => _fetchCartCount());
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: textDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: brandYellow,
                          size: 20,
                        ),
                      ),
                      if (_cartItemCount > 0)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Center(
                              child: Text(
                                _cartItemCount > 99 ? '99+' : '$_cartItemCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
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
        ),
      ),
    );
  }

  Widget _buildBannerCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandYellow.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: textDark, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Tukar Saldo Barang",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textDark),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: textDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 16, color: textDark),
                label: const Text("Pesanan", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrdersPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Gunakan saldo hasil penjemputan sampah untuk mendapatkan produk ramah lingkungan pilihan.",
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 50),
              child: CircularProgressIndicator(color: primaryNavy),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.only(top: 50),
              child: Text("Error: ${snapshot.error}"),
            ),
          );
        }

        final products = snapshot.data ?? [];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: const BoxDecoration(
                  color: textDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.stars_rounded, color: brandYellow, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Katalog Pilihan EcoMart",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: products.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text("Belum ada produk daur ulang tersedia", style: TextStyle(color: Colors.grey)),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) => _buildProductItem(
                          context,
                          products[index] as Map<String, dynamic>,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductItem(BuildContext context, Map<String, dynamic> item) {
    final num priceNum = num.tryParse(item['price'].toString()) ?? 0;
    final String? imageUrl = item['imageUrl'] ?? item['image'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailPage(product: item)),
        ).then((_) => _fetchCartCount());
      },
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: (imageUrl != null && imageUrl.startsWith('http'))
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey),
                        )
                      : const Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['name'] ?? 'Produk',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              _currencyFormat.format(priceNum),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: ecoGreen,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DetailPage(product: item)),
                  ).then((_) => _fetchCartCount());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  foregroundColor: textDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                child: const Text("Tukar Sekarang", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}