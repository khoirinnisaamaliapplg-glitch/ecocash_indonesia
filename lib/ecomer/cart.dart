import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';

class CartScreen extends StatefulWidget {
  /// Dapat dikirim dari halaman pemilihan alamat.
  final int? addressId;

  const CartScreen({
    super.key,
    this.addressId,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic> cartData = {
    'stores': [],
    'summary': {
      'totalItems': 0,
      'totalAmount': 0,
    },
  };

  final Set<int> selectedItemIds = {};
  final Set<int> processingItemIds = {};

  final TextEditingController voucherController =
      TextEditingController();

  final TextEditingController notesController =
      TextEditingController();

  bool isLoading = true;
  bool isCheckingOut = false;
  bool isClearing = false;

  bool _selectionInitialized = false;

  String paymentMethod = 'WALLET';

  Map<String, String> get _jsonHeaders => {
        ...ApiConfig.headers,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    fetchCart();
  }

  @override
  void dispose() {
    voucherController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ============================================================
  // GET CART
  // ============================================================

  Future<void> fetchCart({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getCart),
        headers: ApiConfig.headers,
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        Map<String, dynamic> result = {};

        if (decoded is Map<String, dynamic>) {
          // GET /cart backend Anda mengembalikan langsung:
          // {
          //   stores: [],
          //   summary: {}
          // }

          if (decoded.containsKey('stores')) {
            result = decoded;
          }

          // Jaga-jaga kalau nanti backend dibuat memakai success()
          else if (decoded['data'] is Map) {
            result =
                Map<String, dynamic>.from(decoded['data']);
          }
        }

        final allIds = _extractAllItemIds(result);

        if (!_selectionInitialized) {
          selectedItemIds
            ..clear()
            ..addAll(allIds);

          _selectionInitialized = true;
        } else {
          // Buang ID item yang sudah tidak ada di cart.
          selectedItemIds.removeWhere(
            (id) => !allIds.contains(id),
          );
        }

        if (!mounted) return;

        setState(() {
          cartData = result;
          isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        _showError(
          _getApiMessage(
            decoded,
            fallback: 'Gagal mengambil keranjang.',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showError(
        'Terjadi kesalahan koneksi.\n$e',
      );
    }
  }

  // ============================================================
  // UPDATE QUANTITY
  // ============================================================

  Future<void> updateQuantity(
    int itemId,
    int newQuantity,
  ) async {
    if (processingItemIds.contains(itemId)) {
      return;
    }

    if (newQuantity <= 0) {
      await removeItem(itemId);
      return;
    }

    setState(() {
      processingItemIds.add(itemId);
    });

    try {
      final response = await http.patch(
        Uri.parse(
          ApiConfig.updateCartItem(itemId),
        ),
        headers: _jsonHeaders,
        body: jsonEncode({
          'quantity': newQuantity,
        }),
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        await fetchCart(
          showLoading: false,
        );
      } else {
        _showError(
          _getApiMessage(
            decoded,
            fallback:
                'Gagal mengubah jumlah produk.',
          ),
        );
      }
    } catch (e) {
      _showError(
        'Terjadi kesalahan koneksi.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          processingItemIds.remove(itemId);
        });
      }
    }
  }

  // ============================================================
  // REMOVE ITEM
  // ============================================================

  Future<void> removeItem(
    int itemId, {
    bool confirmation = false,
  }) async {
    if (processingItemIds.contains(itemId)) {
      return;
    }

    if (confirmation) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Hapus Produk',
            ),
            content: const Text(
              'Apakah Anda yakin ingin menghapus produk ini dari keranjang?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    false,
                  );
                },
                child: const Text(
                  'Batal',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    true,
                  );
                },
                child: const Text(
                  'Hapus',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (result != true) {
        return;
      }
    }

    setState(() {
      processingItemIds.add(itemId);
    });

    try {
      final response = await http.delete(
        Uri.parse(
          ApiConfig.removeCartItem(itemId),
        ),
        headers: ApiConfig.headers,
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        selectedItemIds.remove(itemId);

        await fetchCart(
          showLoading: false,
        );
      } else {
        _showError(
          _getApiMessage(
            decoded,
            fallback:
                'Gagal menghapus produk.',
          ),
        );
      }
    } catch (e) {
      _showError(
        'Terjadi kesalahan koneksi.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          processingItemIds.remove(itemId);
        });
      }
    }
  }

  // ============================================================
  // CLEAR CART
  // ============================================================

  Future<void> clearCart() async {
    if (_allItems.isEmpty) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Kosongkan Keranjang',
          ),
          content: const Text(
            'Semua produk di dalam keranjang akan dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Batal',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Kosongkan',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      isClearing = true;
    });

    try {
      final response = await http.delete(
        Uri.parse(
          ApiConfig.clearCart,
        ),
        headers: ApiConfig.headers,
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        selectedItemIds.clear();

        await fetchCart(
          showLoading: false,
        );

        _showSuccess(
          'Keranjang berhasil dikosongkan.',
        );
      } else {
        _showError(
          _getApiMessage(
            decoded,
            fallback:
                'Gagal mengosongkan keranjang.',
          ),
        );
      }
    } catch (e) {
      _showError(
        'Terjadi kesalahan koneksi.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          isClearing = false;
        });
      }
    }
  }

  // ============================================================
  // PREVIEW CHECKOUT
  // ============================================================

  Future<Map<String, dynamic>?> previewCheckout() async {
    if (selectedItemIds.isEmpty) {
      _showError(
        'Pilih minimal satu produk untuk checkout.',
      );

      return null;
    }

    try {
      final Map<String, dynamic> body = {
        'itemIds': selectedItemIds.toList(),
      };

      final voucher =
          voucherController.text.trim();

      if (voucher.isNotEmpty) {
        body['voucherCode'] = voucher;
      }

      final response = await http.post(
        Uri.parse(
          ApiConfig.previewCart,
        ),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map) {
            return Map<String, dynamic>.from(
              decoded['data'],
            );
          }

          return decoded;
        }

        return {};
      }

      _showError(
        _getApiMessage(
          decoded,
          fallback:
              'Preview checkout gagal.',
        ),
      );

      return null;
    } catch (e) {
      _showError(
        'Tidak dapat melakukan preview checkout.\n$e',
      );

      return null;
    }
  }

  // ============================================================
  // CHECKOUT
  // ============================================================

  Future<void> checkout() async {
    if (selectedItemIds.isEmpty) {
      _showError(
        'Pilih minimal satu produk.',
      );

      return;
    }

    if (isCheckingOut) {
      return;
    }

    setState(() {
      isCheckingOut = true;
    });

    try {
      final Map<String, dynamic> body = {
        'itemIds': selectedItemIds.toList(),
        'paymentMethod': paymentMethod,
      };

      final voucher =
          voucherController.text.trim();

      final notes =
          notesController.text.trim();

      if (voucher.isNotEmpty) {
        body['voucherCode'] = voucher;
      }

      if (notes.isNotEmpty) {
        body['notes'] = notes;
      }

      if (widget.addressId != null) {
        body['addressId'] =
            widget.addressId;
      }

      final response = await http.post(
        Uri.parse(
          ApiConfig.checkoutCart,
        ),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        String message =
            'Checkout berhasil.';

        if (decoded is Map<String, dynamic>) {
          message =
              decoded['message']?.toString() ??
                  message;
        }

        if (!mounted) return;

        Navigator.pop(
          context,
        );

        _showSuccess(
          message,
        );

        // WALLET:
        // backend langsung menghapus item yang sudah dibeli.
        //
        // MIDTRANS:
        // item tetap ada sampai payment settlement.
        if (paymentMethod == 'WALLET') {
          selectedItemIds.clear();

          await fetchCart(
            showLoading: false,
          );
        }
      } else {
        _showError(
          _getApiMessage(
            decoded,
            fallback: 'Checkout gagal.',
          ),
        );
      }
    } catch (e) {
      _showError(
        'Terjadi kesalahan ketika checkout.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          isCheckingOut = false;
        });
      }
    }
  }

  // ============================================================
  // CHECKOUT FLOW
  // ============================================================

  Future<void> openCheckout() async {
    if (selectedItemIds.isEmpty) {
      _showError(
        'Pilih produk yang ingin dibeli.',
      );

      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(context)
                            .viewInsets
                            .bottom +
                        24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                                Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      const Text(
                        'Checkout',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        '${selectedItemIds.length} produk dipilih',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      DropdownButtonFormField<String>(
                        value: paymentMethod,
                        decoration:
                            _inputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: 'WALLET',
                            child:
                                Text('EcoCash Wallet'),
                          ),
                          DropdownMenuItem(
                            value: 'MIDTRANS',
                            child:
                                Text('Midtrans'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            paymentMethod =
                                value;
                          });

                          setModalState(() {});
                        },
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'Voucher',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                            voucherController,
                        textCapitalization:
                            TextCapitalization
                                .characters,
                        decoration:
                            _inputDecoration(
                          hint:
                              'Masukkan kode voucher',
                          prefixIcon:
                              Icons.local_offer_outlined,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'Catatan',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                            notesController,
                        maxLines: 3,
                        decoration:
                            _inputDecoration(
                          hint:
                              'Catatan untuk pesanan',
                        ),
                      ),

                      if (widget.addressId !=
                          null) ...[
                        const SizedBox(
                          height: 18,
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .all(14),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.grey.shade50,
                            borderRadius:
                                BorderRadius
                                    .circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .location_on_outlined,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Alamat ID: ${widget.addressId}',
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 24,
                      ),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                          ),
                          Text(
                            'Rp${_rupiah(selectedTotal)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              isCheckingOut
                                  ? null
                                  : () async {
                                      final preview =
                                          await previewCheckout();

                                      if (preview ==
                                          null) {
                                        return;
                                      }

                                      if (!mounted) {
                                        return;
                                      }

                                      await _showPreviewDialog(
                                        preview,
                                      );
                                    },
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF0A8F61,
                            ),
                            foregroundColor:
                                Colors.white,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                          ),
                          child: isCheckingOut
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Preview Checkout',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
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

  Future<void> _showPreviewDialog(
    Map<String, dynamic> preview,
  ) async {
    final serverTotal = _findNumberByKeys(
      preview,
      [
        'grandTotal',
        'finalTotal',
        'totalAmount',
        'total',
      ],
    );

    final discount = _findNumberByKeys(
      preview,
      [
        'discountAmount',
        'discount',
        'voucherDiscount',
      ],
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Konfirmasi Pesanan',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _previewRow(
                'Produk',
                '${selectedItemIds.length} item',
              ),
              _previewRow(
                'Subtotal',
                'Rp${_rupiah(selectedTotal)}',
              ),
              if (discount != null)
                _previewRow(
                  'Diskon',
                  '- Rp${_rupiah(discount)}',
                ),
              if (serverTotal != null)
                _previewRow(
                  'Total',
                  'Rp${_rupiah(serverTotal)}',
                  bold: true,
                ),
              _previewRow(
                'Pembayaran',
                paymentMethod,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Batal',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Checkout',
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await checkout();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Keranjang Saya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_allItems.isNotEmpty)
            TextButton(
              onPressed:
                  isClearing ? null : clearCart,
              child: isClearing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Hapus Semua',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _allItems.isEmpty
              ? _buildEmptyCart()
              : RefreshIndicator(
                  onRefresh: fetchCart,
                  child: ListView(
                    padding:
                        const EdgeInsets.only(
                      top: 12,
                      bottom: 130,
                    ),
                    children: [
                      _buildSelectAll(),

                      ..._stores.map(
                        (store) =>
                            _buildStoreCard(
                          store,
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar:
          _allItems.isEmpty
              ? null
              : _buildCheckoutBar(),
    );
  }

  // ============================================================
  // SELECT ALL
  // ============================================================

  Widget _buildSelectAll() {
    final allIds =
        _extractAllItemIds(cartData);

    final allSelected =
        allIds.isNotEmpty &&
            allIds.every(
              selectedItemIds.contains,
            );

    return Container(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            activeColor:
                const Color(0xFF0A8F61),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  selectedItemIds.addAll(
                    allIds,
                  );
                } else {
                  selectedItemIds.clear();
                }
              });
            },
          ),
          const Text(
            'Pilih Semua',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STORE CARD
  // ============================================================

  Widget _buildStoreCard(
    Map<String, dynamic> store,
  ) {
    final items =
        List<Map<String, dynamic>>.from(
      store['items'] ?? [],
    );

    final storeIds = items
        .map((item) => _toInt(item['id']))
        .whereType<int>()
        .toList();

    final allStoreSelected =
        storeIds.isNotEmpty &&
            storeIds.every(
              selectedItemIds.contains,
            );

    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              10,
              8,
              16,
              8,
            ),
            child: Row(
              children: [
                Checkbox(
                  value:
                      allStoreSelected,
                  activeColor:
                      const Color(
                    0xFF0A8F61,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedItemIds
                            .addAll(
                          storeIds,
                        );
                      } else {
                        selectedItemIds
                            .removeAll(
                          storeIds,
                        );
                      }
                    });
                  },
                ),
                const Icon(
                  Icons.storefront_outlined,
                  size: 21,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    store['storeName']
                            ?.toString() ??
                        'Toko',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          ...items.map(
            _buildCartItem,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CART ITEM
  // ============================================================

  Widget _buildCartItem(
    Map<String, dynamic> item,
  ) {
    final int itemId =
        _toInt(item['id']) ?? 0;

    final int quantity =
        _toInt(item['quantity']) ?? 1;

    final product =
        Map<String, dynamic>.from(
      item['product'] ?? {},
    );

    final normalPrice =
        _toNum(product['price']);

    final discountPrice =
        _toNullableNum(
      product['discountPrice'],
    );

    final effectivePrice = _toNum(
      product['effectivePrice'] ??
          discountPrice ??
          normalPrice,
    );

    final subtotal = _toNum(
      item['subtotal'] ??
          (effectivePrice * quantity),
    );

    final selected =
        selectedItemIds.contains(itemId);

    final processing =
        processingItemIds
            .contains(itemId);

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            activeColor:
                const Color(0xFF0A8F61),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  selectedItemIds
                      .add(itemId);
                } else {
                  selectedItemIds
                      .remove(itemId);
                }
              });
            },
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  product['name']
                          ?.toString() ??
                      'Produk',
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                if (discountPrice !=
                    null) ...[
                  Text(
                    'Rp${_rupiah(normalPrice)}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade500,
                      decoration:
                          TextDecoration
                              .lineThrough,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                ],

                Text(
                  'Rp${_rupiah(effectivePrice)}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF0A8F61),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Row(
                  children: [
                    _quantityButton(
                      icon: quantity <= 1
                          ? Icons
                              .delete_outline
                          : Icons.remove,
                      onTap: processing
                          ? null
                          : () {
                              if (quantity >
                                  1) {
                                updateQuantity(
                                  itemId,
                                  quantity -
                                      1,
                                );
                              } else {
                                removeItem(
                                  itemId,
                                );
                              }
                            },
                    ),

                    SizedBox(
                      width: 38,
                      child: Center(
                        child: processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : Text(
                                quantity
                                    .toString(),
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                      ),
                    ),

                    _quantityButton(
                      icon: Icons.add,
                      onTap: processing
                          ? null
                          : () {
                              updateQuantity(
                                itemId,
                                quantity +
                                    1,
                              );
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: processing
                    ? null
                    : () {
                        removeItem(
                          itemId,
                          confirmation:
                              true,
                        );
                      },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
              ),

              Text(
                'Rp${_rupiah(subtotal)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
          ),
          borderRadius:
              BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM CHECKOUT
  // ============================================================

  Widget _buildCheckoutBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          14,
          20,
          14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.08,
              ),
              blurRadius: 15,
              offset:
                  const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedItemIds.length} item dipilih',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Rp${_rupiah(selectedTotal)}',
                    style:
                        const TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed:
                    selectedItemIds.isEmpty
                        ? null
                        : openCheckout,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF0A8F61,
                  ),
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 28,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(14),
                  ),
                ),
                child: const Text(
                  'Checkout',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY CART
  // ============================================================

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .shopping_cart_outlined,
              size: 80,
              color:
                  Colors.grey.shade300,
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'Keranjang masih kosong',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Tambahkan produk yang ingin Anda beli ke keranjang.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CALCULATION
  // ============================================================

  List<Map<String, dynamic>>
      get _stores {
    final stores =
        cartData['stores'];

    if (stores is! List) {
      return [];
    }

    return stores
        .map(
          (e) =>
              Map<String, dynamic>.from(
            e,
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>>
      get _allItems {
    final List<Map<String, dynamic>>
        items = [];

    for (final store in _stores) {
      final storeItems =
          store['items'];

      if (storeItems is List) {
        for (final item
            in storeItems) {
          items.add(
            Map<String, dynamic>.from(
              item,
            ),
          );
        }
      }
    }

    return items;
  }

  num get selectedTotal {
    num total = 0;

    for (final item in _allItems) {
      final id =
          _toInt(item['id']);

      if (id == null ||
          !selectedItemIds.contains(id)) {
        continue;
      }

      total +=
          _toNum(item['subtotal']);
    }

    return total;
  }

  Set<int> _extractAllItemIds(
    Map<String, dynamic> data,
  ) {
    final Set<int> ids = {};

    final stores = data['stores'];

    if (stores is! List) {
      return ids;
    }

    for (final store in stores) {
      if (store is! Map) continue;

      final items = store['items'];

      if (items is! List) continue;

      for (final item in items) {
        if (item is! Map) continue;

        final id =
            _toInt(item['id']);

        if (id != null) {
          ids.add(id);
        }
      }
    }

    return ids;
  }

  // ============================================================
  // API HELPERS
  // ============================================================

  dynamic _decodeResponse(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return {};
    }

    try {
      return jsonDecode(
        response.body,
      );
    } catch (_) {
      return {};
    }
  }

  String _getApiMessage(
    dynamic data, {
    required String fallback,
  }) {
    if (data is Map) {
      if (data['message'] != null) {
        return data['message']
            .toString();
      }

      if (data['error'] is Map &&
          data['error']['message'] !=
              null) {
        return data['error']
                ['message']
            .toString();
      }
    }

    return fallback;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  num _toNum(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value;
    }

    return num.tryParse(
          value.toString(),
        ) ??
        0;
  }

  num? _toNullableNum(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value;
    }

    return num.tryParse(
      value.toString(),
    );
  }

  String _rupiah(num value) {
    final raw =
        value.round().toString();

    return raw.replaceAllMapped(
      RegExp(
        r'\B(?=(\d{3})+(?!\d))',
      ),
      (_) => '.',
    );
  }

  num? _findNumberByKeys(
    dynamic data,
    List<String> keys,
  ) {
    if (data is Map) {
      for (final key in keys) {
        if (data[key] != null) {
          final number =
              _toNullableNum(
            data[key],
          );

          if (number != null) {
            return number;
          }
        }
      }

      for (final value
          in data.values) {
        final found =
            _findNumberByKeys(
          value,
          keys,
        );

        if (found != null) {
          return found;
        }
      }
    }

    if (data is List) {
      for (final item in data) {
        final found =
            _findNumberByKeys(
          item,
          keys,
        );

        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  Widget _previewRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon)
          : null,
      filled: true,
      fillColor:
          const Color(0xFFF7F8FA),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color: Color(0xFF0A8F61),
        ),
      ),
    );
  }

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              Colors.red.shade700,
          content: Text(message),
        ),
      );
  }

  void _showSuccess(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(
            0xFF0A8F61,
          ),
          content: Text(message),
        ),
      );
  }
}