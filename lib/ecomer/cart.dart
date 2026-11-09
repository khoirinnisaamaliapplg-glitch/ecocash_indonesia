import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/voucher/voucher.dart';
import 'package:ecocash_indonesia/profile/daftar_alamat_page.dart';

class CartScreen extends StatefulWidget {
  final int? addressId;

  const CartScreen({
    super.key,
    this.addressId,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  Map<String, dynamic> cartData = {
    'stores': [],
    'summary': {
      'totalItems': 0,
      'totalAmount': 0,
    },
  };

  final Set<int> selectedItemIds = {};
  final Set<int> processingItemIds = {};

  final TextEditingController voucherController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool isLoading = true;
  bool isCheckingOut = false;
  bool isClearing = false;
  bool _selectionInitialized = false;

  String paymentMethod = 'WALLET';
  int? _activeAddressId;
  String _addressLabel = 'Memuat alamat pengiriman...';

  Map<String, String> get _jsonHeaders => {
        ...ApiConfig.headers,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _activeAddressId = widget.addressId;
    fetchCart();
    _fetchInitialAddress();
  }

  @override
  void dispose() {
    voucherController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialAddress() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getUserAddresses),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawList = decoded['data'];
        final list = rawList is List ? rawList : [];
        if (list.isNotEmpty) {
          final selected = _activeAddressId != null
              ? list.firstWhere((a) => a['id'] == _activeAddressId, orElse: () => list.first)
              : list.firstWhere((a) => a['isDefault'] == true, orElse: () => list.first);

          if (mounted) {
            setState(() {
              _activeAddressId = selected['id'];
              _addressLabel = "${selected['label']} - ${selected['detail'] ?? selected['address']}";
            });
          }
        } else {
          if (mounted) setState(() => _addressLabel = 'Belum ada alamat tersimpan');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _addressLabel = 'Alamat Pengiriman Default');
    }
  }

  Future<void> fetchCart({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getCart),
        headers: ApiConfig.headers,
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic> result = {};

        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('stores')) {
            result = decoded;
          } else if (decoded['data'] is Map) {
            result = Map<String, dynamic>.from(decoded['data']);
          }
        }

        final allIds = _extractAllItemIds(result);

        if (!_selectionInitialized) {
          selectedItemIds
            ..clear()
            ..addAll(allIds);
          _selectionInitialized = true;
        } else {
          selectedItemIds.removeWhere((id) => !allIds.contains(id));
        }

        if (!mounted) return;
        setState(() {
          cartData = result;
          isLoading = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
        _showError(_getApiMessage(decoded, fallback: 'Gagal mengambil keranjang.'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showError('Terjadi kesalahan koneksi.\n$e');
    }
  }

  Future<void> updateQuantity(int itemId, int newQuantity) async {
    if (processingItemIds.contains(itemId)) return;
    if (newQuantity <= 0) {
      await removeItem(itemId);
      return;
    }

    setState(() => processingItemIds.add(itemId));

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.updateCartItem(itemId)),
        headers: _jsonHeaders,
        body: jsonEncode({'quantity': newQuantity}),
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await fetchCart(showLoading: false);
      } else {
        _showError(_getApiMessage(decoded, fallback: 'Gagal mengubah jumlah produk.'));
      }
    } catch (e) {
      _showError('Terjadi kesalahan koneksi.\n$e');
    } finally {
      if (mounted) setState(() => processingItemIds.remove(itemId));
    }
  }

  Future<void> removeItem(int itemId, {bool confirmation = false}) async {
    if (processingItemIds.contains(itemId)) return;

    if (confirmation) {
      final dynamic result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Hapus Produk', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Apakah Anda yakin ingin menghapus produk ini dari keranjang?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
      if (result != true) return;
    }

    setState(() => processingItemIds.add(itemId));

    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.removeCartItem(itemId)),
        headers: ApiConfig.headers,
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        selectedItemIds.remove(itemId);
        await fetchCart(showLoading: false);
      } else {
        _showError(_getApiMessage(decoded, fallback: 'Gagal menghapus produk.'));
      }
    } catch (e) {
      _showError('Terjadi kesalahan koneksi.\n$e');
    } finally {
      if (mounted) setState(() => processingItemIds.remove(itemId));
    }
  }

  Future<void> clearCart() async {
    if (_allItems.isEmpty) return;

    final dynamic confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Kosongkan Keranjang', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Semua produk di dalam keranjang akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kosongkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    setState(() => isClearing = true);

    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.clearCart),
        headers: ApiConfig.headers,
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        selectedItemIds.clear();
        await fetchCart(showLoading: false);
        _showSuccess('Keranjang berhasil dikosongkan.');
      } else {
        _showError(_getApiMessage(decoded, fallback: 'Gagal mengosongkan keranjang.'));
      }
    } catch (e) {
      _showError('Terjadi kesalahan koneksi.\n$e');
    } finally {
      if (mounted) setState(() => isClearing = false);
    }
  }

  Future<dynamic> previewCheckout() async {
    if (selectedItemIds.isEmpty) {
      _showError('Pilih minimal satu produk untuk checkout.');
      return null;
    }

    try {
      final Map<String, dynamic> body = {
        'itemIds': selectedItemIds.toList(),
      };

      final voucher = voucherController.text.trim();
      if (voucher.isNotEmpty) {
        body['voucherCode'] = voucher;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.previewCart),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map) {
            return Map<String, dynamic>.from(decoded['data']);
          }
          return decoded;
        }
        return {};
      }

      _showError(_getApiMessage(decoded, fallback: 'Preview checkout gagal.'));
      return null;
    } catch (e) {
      _showError('Tidak dapat melakukan preview checkout.\n$e');
      return null;
    }
  }

  Future<void> checkout() async {
    if (selectedItemIds.isEmpty) {
      _showError('Pilih minimal satu produk.');
      return;
    }

    if (isCheckingOut) return;
    setState(() => isCheckingOut = true);

    try {
      final Map<String, dynamic> body = {
        'itemIds': selectedItemIds.toList(),
        'paymentMethod': paymentMethod,
      };

      final voucher = voucherController.text.trim();
      final notes = notesController.text.trim();

      if (voucher.isNotEmpty) body['voucherCode'] = voucher;
      if (notes.isNotEmpty) body['notes'] = notes;
      if (_activeAddressId != null) body['addressId'] = _activeAddressId;

      final response = await http.post(
        Uri.parse(ApiConfig.checkoutCart),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String message = 'Checkout berhasil.';
        if (decoded is Map<String, dynamic>) {
          message = decoded['message']?.toString() ?? message;
        }

        if (!mounted) return;
        Navigator.pop(context);
        _showSuccess(message);

        if (paymentMethod == 'WALLET') {
          selectedItemIds.clear();
          voucherController.clear();
          notesController.clear();
          await fetchCart(showLoading: false);
        }
      } else {
        _showError(_getApiMessage(decoded, fallback: 'Checkout gagal.'));
      }
    } catch (e) {
      _showError('Terjadi kesalahan ketika checkout.\n$e');
    } finally {
      if (mounted) setState(() => isCheckingOut = false);
    }
  }

  Future<void> openCheckout() async {
    if (selectedItemIds.isEmpty) {
      _showError('Pilih produk yang ingin dibeli.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Konfirmasi Pembelian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                      const SizedBox(height: 4),
                      Text('${selectedItemIds.length} produk siap diproses', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 18),

                      const Text('Alamat Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: surfaceBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _addressLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final dynamic selected = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const DaftarAlamatPage(isSelecting: true)),
                                );
                                if (selected != null && selected is Map) {
                                  setModalState(() {
                                    _activeAddressId = selected['id'];
                                    _addressLabel = "${selected['label']} - ${selected['detail'] ?? selected['address']}";
                                  });
                                }
                              },
                              child: const Text('Ganti', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: paymentMethod,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'WALLET', child: Text('EcoCash Wallet (Saldo Bank Sampah)')),
                          DropdownMenuItem(value: 'MIDTRANS', child: Text('Gateway Midtrans')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => paymentMethod = value);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 14),

                      const Text('Voucher Promo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: voucherController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _inputDecoration(
                                hint: 'Ketik atau pilih voucher',
                                prefixIcon: Icons.confirmation_number_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final dynamic result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const VoucherPage()),
                              );
                              if (result != null && result is Map && result['code'] != null) {
                                setModalState(() {
                                  voucherController.text = result['code'].toString();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandYellow,
                              foregroundColor: textDark,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Pilih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const Text('Catatan Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: _inputDecoration(hint: 'Instruksi kemasan atau pengiriman...'),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal Pesanan', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            'Rp${_rupiah(selectedTotal)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isCheckingOut
                              ? null
                              : () async {
                                  final dynamic preview = await previewCheckout();
                                  if (preview == null || !mounted) return;
                                  await _showPreviewDialog(preview);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandYellow,
                            foregroundColor: textDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: isCheckingOut
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textDark))
                              : const Text('Preview & Konfirmasi Bayar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPreviewDialog(dynamic preview) async {
    final serverTotal = _findNumberByKeys(preview, ['grandTotal', 'finalTotal', 'totalAmount', 'total']);
    final discount = _findNumberByKeys(preview, ['discountAmount', 'discount', 'voucherDiscount']);

    final dynamic confirm = await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Rincian Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _previewRow('Produk Terpilih', '${selectedItemIds.length} item'),
              _previewRow('Subtotal', 'Rp${_rupiah(selectedTotal)}'),
              if (discount != null && discount > 0)
                _previewRow('Diskon Voucher', '- Rp${_rupiah(discount)}'),
              if (serverTotal != null)
                _previewRow('Total Tagihan', 'Rp${_rupiah(serverTotal)}', bold: true),
              _previewRow('Metode Pembayaran', paymentMethod == 'WALLET' ? 'EcoCash Wallet' : 'Midtrans'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: textDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await checkout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: brandYellow,
        title: const Text('Keranjang Saya', style: TextStyle(fontWeight: FontWeight.w900, color: textDark, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_allItems.isNotEmpty)
            TextButton(
              onPressed: isClearing ? null : clearCart,
              child: isClearing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: textDark))
                  : const Text('Hapus Semua', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryNavy))
          : _allItems.isEmpty
              ? _buildEmptyCart()
              : RefreshIndicator(
                  onRefresh: fetchCart,
                  color: textDark,
                  backgroundColor: brandYellow,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 130),
                    children: [
                      _buildSelectAll(),
                      ..._stores.map((store) => _buildStoreCard(store)),
                    ],
                  ),
                ),
      bottomNavigationBar: _allItems.isEmpty ? null : _buildCheckoutBar(),
    );
  }

  Widget _buildSelectAll() {
    final allIds = _extractAllItemIds(cartData);
    final allSelected = allIds.isNotEmpty && allIds.every(selectedItemIds.contains);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            activeColor: textDark,
            checkColor: brandYellow,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  selectedItemIds.addAll(allIds);
                } else {
                  selectedItemIds.clear();
                }
              });
            },
          ),
          const Text('Pilih Semua Produk', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        ],
      ),
    );
  }

  Widget _buildStoreCard(dynamic rawStore) {
    if (rawStore is! Map) return const SizedBox.shrink();
    final store = Map<String, dynamic>.from(rawStore);
    final rawStoreItems = store['items'];
    final rawList = rawStoreItems is List ? rawStoreItems : [];
    final items = rawList.whereType().map((e) => Map<String, dynamic>.from(e)).toList();

    final storeIds = items
        .map((item) => _toInt(item['id']))
        .whereType<int>()
        .toList();

    final bool allStoreSelected = storeIds.isNotEmpty && storeIds.every(selectedItemIds.contains);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
            child: Row(
              children: [
                Checkbox(
                  value: allStoreSelected,
                  activeColor: textDark,
                  checkColor: brandYellow,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedItemIds.addAll(storeIds);
                      } else {
                        selectedItemIds.removeAll(storeIds);
                      }
                    });
                  },
                ),
                const Icon(Icons.storefront_rounded, size: 20, color: textDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    store['storeName']?.toString() ?? 'Toko EcoCash',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ...items.map((it) => _buildCartItem(it)),
        ],
      ),
    );
  }

  Widget _buildCartItem(dynamic rawItem) {
    if (rawItem is! Map) return const SizedBox.shrink();
    final item = Map<String, dynamic>.from(rawItem);
    final int itemId = _toInt(item['id']) ?? 0;
    final int quantity = _toInt(item['quantity']) ?? 1;
    final product = Map<String, dynamic>.from(item['product'] ?? {});
    final normalPrice = _toNum(product['price']);
    final discountPrice = _toNullableNum(product['discountPrice']);
    final effectivePrice = _toNum(product['effectivePrice'] ?? discountPrice ?? normalPrice);
    final subtotal = _toNum(item['subtotal'] ?? (effectivePrice * quantity));
    final selected = selectedItemIds.contains(itemId);
    final processing = processingItemIds.contains(itemId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            activeColor: textDark,
            checkColor: brandYellow,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  selectedItemIds.add(itemId);
                } else {
                  selectedItemIds.remove(itemId);
                }
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name']?.toString() ?? 'Produk Daur Ulang',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                ),
                const SizedBox(height: 3),
                if (discountPrice != null) ...[
                  Text(
                    'Rp${_rupiah(normalPrice)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                Text(
                  'Rp${_rupiah(effectivePrice)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: ecoGreen, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _quantityButton(
                      icon: quantity <= 1 ? Icons.delete_outline : Icons.remove,
                      onTap: processing
                          ? null
                          : () {
                              if (quantity > 1) {
                                updateQuantity(itemId, quantity - 1);
                              } else {
                                removeItem(itemId);
                              }
                            },
                    ),
                    SizedBox(
                      width: 34,
                      child: Center(
                        child: processing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: textDark))
                            : Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    _quantityButton(
                      icon: Icons.add,
                      onTap: processing ? null : () => updateQuantity(itemId, quantity + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: processing ? null : () => removeItem(itemId, confirmation: true),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
              ),
              Text('Rp${_rupiah(subtotal)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: textDark),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${selectedItemIds.length} item dipilih', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  Text('Rp${_rupiah(selectedTotal)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: selectedItemIds.isEmpty ? null : openCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  foregroundColor: textDark,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: brandYellow.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.shopping_cart_outlined, size: 50, color: textDark),
            ),
            const SizedBox(height: 16),
            const Text('Keranjang masih kosong', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark)),
            const SizedBox(height: 6),
            const Text('Tukarkan saldo daur ulang dengan barang pilihan Anda.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  List<dynamic> get _stores {
    final stores = cartData['stores'];
    if (stores is! List) return [];
    return stores;
  }

  List<dynamic> get _allItems {
    final List<dynamic> items = [];
    for (final store in _stores) {
      if (store is Map) {
        final storeItems = store['items'];
        if (storeItems is List) {
          items.addAll(storeItems);
        }
      }
    }
    return items;
  }

  num get selectedTotal {
    num total = 0;
    for (final item in _allItems) {
      if (item is! Map) continue;
      final id = _toInt(item['id']);
      if (id == null || !selectedItemIds.contains(id)) continue;
      total += _toNum(item['subtotal']);
    }
    return total;
  }

  Set<int> _extractAllItemIds(dynamic data) {
    final Set<int> ids = {};
    if (data is! Map) return ids;
    final stores = data['stores'];
    if (stores is! List) return ids;
    for (final store in stores) {
      if (store is! Map) continue;
      final items = store['items'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final id = _toInt(item['id']);
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) return {};
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {};
    }
  }

  String _getApiMessage(dynamic data, {required String fallback}) {
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] is Map && data['error']['message'] != null) {
        return data['error']['message'].toString();
      }
    }
    return fallback;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  num? _toNullableNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  String _rupiah(num value) {
    final raw = value.round().toString();
    return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }

  num? _findNumberByKeys(dynamic data, List<String> keys) {
    if (data is Map) {
      for (final key in keys) {
        if (data[key] != null) {
          final number = _toNullableNum(data[key]);
          if (number != null) return number;
        }
      }
      for (final value in data.values) {
        final found = _findNumberByKeys(value, keys);
        if (found != null) return found;
      }
    }
    if (data is List) {
      for (final item in data) {
        final found = _findNumberByKeys(item, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  Widget _previewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
              fontSize: 13,
              color: bold ? ecoGreen : textDark,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: textDark) : null,
      filled: true,
      fillColor: surfaceBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: textDark, width: 1.5)),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(backgroundColor: Colors.red.shade700, content: Text(message)));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(backgroundColor: ecoGreen, content: Text(message)));
  }
}