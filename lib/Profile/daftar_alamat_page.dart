import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../ipconfig.dart';

class DaftarAlamatPage extends StatefulWidget {
  final bool isSelecting;

  const DaftarAlamatPage({super.key, this.isSelecting = false});

  @override
  State<DaftarAlamatPage> createState() => _DaftarAlamatPageState();
}

class _DaftarAlamatPageState extends State<DaftarAlamatPage> {
  final Color primary = const Color(0xff0BCFD1);
  bool _isLoading = true;
  List<dynamic> _addresses = [];

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getUserAddresses),
        headers: ApiConfig.headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list = [];
        if (decoded['data'] is List) {
          list = decoded['data'];
        } else if (decoded['data'] is Map && decoded['data']['addresses'] is List) {
          list = decoded['data']['addresses'];
        }

        setState(() {
          _addresses = list;
        });
      } else {
        debugPrint("Gagal mengambil alamat: ${res.statusCode} - ${res.body}");
      }
    } catch (e) {
      debugPrint("Gagal memuat alamat: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefaultAddress(int id) async {
    try {
      final res = await http.patch(
        Uri.parse(ApiConfig.setDefaultAddress(id)),
        headers: ApiConfig.headers,
      );

      if (res.statusCode == 200) {
        _fetchAddresses();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menetapkan alamat utama: ${res.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Gagal mengubah alamat default: $e");
    }
  }

  Future<void> _deleteAddress(int id) async {
    try {
      final res = await http.delete(
        Uri.parse(ApiConfig.deleteUserAddress(id)),
        headers: ApiConfig.headers,
      );

      if (res.statusCode == 200) {
        _fetchAddresses();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus alamat: ${res.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Gagal menghapus alamat: $e");
    }
  }

  // Preset koordinat kota dan area operasional EcoCash
  final Map<String, Map<String, dynamic>> _areaPresets = {
    'Bandung (Sukajadi/Pasteur)': {
      'province': 'JAWA BARAT',
      'city': 'KOTA BANDUNG',
      'district': 'SUKAJADI',
      'subdistrict': 'PASTEUR',
      'postalCode': '40161',
      'lat': -6.8942,
      'lng': 107.6033,
    },
    'Bandung (Pusat/Asia Afrika)': {
      'province': 'JAWA BARAT',
      'city': 'KOTA BANDUNG',
      'district': 'SUMUR BANDUNG',
      'subdistrict': 'BRAGA',
      'postalCode': '40111',
      'lat': -6.9175,
      'lng': 107.6191,
    },
    'Jakarta (Sudirman/Setiabudi)': {
      'province': 'DKI JAKARTA',
      'city': 'JAKARTA SELATAN',
      'district': 'SETIABUDI',
      'subdistrict': 'KARET KUNINGAN',
      'postalCode': '12940',
      'lat': -6.2088,
      'lng': 106.8227,
    },
    'Jakarta (Gambir/Monas)': {
      'province': 'DKI JAKARTA',
      'city': 'JAKARTA PUSAT',
      'district': 'GAMBIR',
      'subdistrict': 'PETOJO UTARA',
      'postalCode': '10130',
      'lat': -6.1661,
      'lng': 106.8194,
    },
  };

  void _showAddAddressDialog() {
    final labelCtrl = TextEditingController(text: 'Rumah');
    final recipientCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final postalCodeCtrl = TextEditingController(text: '40161');

    String selectedAreaKey = 'Bandung (Sukajadi/Pasteur)';
    double currentLat = -6.8942;
    double currentLng = 107.6033;
    bool isDefault = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Deteksi koordinat otomatis dari teks detail alamat
          void autoDetectCoordinates(String text) {
            final lower = text.toLowerCase();
            String? matchedKey;

            if (lower.contains('cipaganti') || lower.contains('pasteur') || lower.contains('sukajadi')) {
              matchedKey = 'Bandung (Sukajadi/Pasteur)';
            } else if (lower.contains('bandung') || lower.contains('dago') || lower.contains('asia afrika') || lower.contains('braga')) {
              matchedKey = 'Bandung (Pusat/Asia Afrika)';
            } else if (lower.contains('sudirman') || lower.contains('kuningan') || lower.contains('setiabudi')) {
              matchedKey = 'Jakarta (Sudirman/Setiabudi)';
            } else if (lower.contains('jakarta') || lower.contains('gambir') || lower.contains('monas') || lower.contains('petojo')) {
              matchedKey = 'Jakarta (Gambir/Monas)';
            }

            if (matchedKey != null && matchedKey != selectedAreaKey) {
              final preset = _areaPresets[matchedKey]!;
              setModalState(() {
                selectedAreaKey = matchedKey!;
                currentLat = preset['lat'];
                currentLng = preset['lng'];
                postalCodeCtrl.text = preset['postalCode'];
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tambah Alamat Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Koordinat spasial GPS akan disimpan otomatis ke PostGIS.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),

                  // Pilihan Area / Kota Operasional
                  const Text('Wilayah Operasional:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedAreaKey,
                        items: _areaPresets.keys.map((k) {
                          return DropdownMenuItem<String>(
                            value: k,
                            child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final preset = _areaPresets[val]!;
                            setModalState(() {
                              selectedAreaKey = val;
                              currentLat = preset['lat'];
                              currentLng = preset['lng'];
                              postalCodeCtrl.text = preset['postalCode'];
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Badge Preview Koordinat Spasial
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.my_location, size: 16, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Koordinat Aktif: $currentLat, $currentLng",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                          child: const Text("PostGIS Ready", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(
                      labelText: 'Label Alamat (Rumah, Kantor, Toko)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: recipientCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nama Penerima',
                            hintText: 'Nama lengkap',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Nomor HP',
                            hintText: '0812xxxxxxxx',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Alamat Lengkap (Jalan, No, RT/RW, Wilayah)',
                      hintText: 'Ketik nama jalan/wilayah, koordinat otomatis menyesuaikan...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: autoDetectCoordinates,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: notesCtrl,
                          decoration: InputDecoration(
                            labelText: 'Patokan (Pagar/Warna Rumah)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: postalCodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Kode Pos',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Jadikan Alamat Utama', style: TextStyle(fontSize: 13)),
                    value: isDefault,
                    activeColor: primary,
                    onChanged: (val) => setModalState(() => isDefault = val ?? false),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (detailCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Alamat lengkap tidak boleh kosong")),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        final String fullDetail = notesCtrl.text.trim().isNotEmpty
                            ? '${detailCtrl.text.trim()} (Patokan: ${notesCtrl.text.trim()})'
                            : detailCtrl.text.trim();

                        final activePreset = _areaPresets[selectedAreaKey]!;

                        // Payload lengkap dengan latitude dan longitude murni bertipe numerik
                        final payload = {
                          'label': labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Rumah',
                          'recipientName': recipientCtrl.text.trim().isNotEmpty ? recipientCtrl.text.trim() : 'Warga EcoCash',
                          'phoneNumber': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : '081234567890',
                          'detail': fullDetail,
                          'postalCode': postalCodeCtrl.text.trim().isNotEmpty ? postalCodeCtrl.text.trim() : activePreset['postalCode'],
                          'province': activePreset['province'],
                          'city': activePreset['city'],
                          'district': activePreset['district'],
                          'subdistrict': activePreset['subdistrict'],
                          'latitude': currentLat,
                          'longitude': currentLng,
                          'isDefault': isDefault,
                        };

                        try {
                          final response = await http.post(
                            Uri.parse(ApiConfig.getUserAddresses),
                            headers: ApiConfig.headers,
                            body: jsonEncode(payload),
                          );

                          if (response.statusCode == 200 || response.statusCode == 201) {
                            _fetchAddresses();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Alamat dengan koordinat spasial berhasil disimpan!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menyimpan: ${response.statusCode} - ${response.body}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint("Error menyimpan alamat: $e");
                        }
                      },
                      child: const Text('Simpan Alamat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: Text(
          widget.isSelecting ? 'Pilih Alamat Penjemputan' : 'Daftar Alamat Tersimpan',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Belum ada alamat tersimpan di database', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: primary),
                        onPressed: _showAddAddressDialog,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Tambah Alamat', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _addresses[index];
                    final bool isDefault = item['isDefault'] == true;
                    final String displayAddress = (item['detail'] ?? item['address'] ?? '').toString();
                    final String recipient = (item['recipientName'] ?? '').toString();
                    final String phone = (item['phoneNumber'] ?? '').toString();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDefault ? primary : Colors.grey.shade200, width: isDefault ? 1.5 : 1),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
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
                                  Text(
                                    item['label'] ?? 'Alamat',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Utama',
                                        style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (widget.isSelecting)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.pop(context, item),
                                  child: const Text('Gunakan', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                            ],
                          ),
                          if (recipient.isNotEmpty || phone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$recipient ${phone.isNotEmpty ? "• $phone" : ""}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(displayAddress, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (!isDefault)
                                TextButton(
                                  onPressed: () => _setDefaultAddress(item['id']),
                                  child: const Text('Jadikan Utama', style: TextStyle(fontSize: 12)),
                                )
                              else
                                const SizedBox(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteAddress(item['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        onPressed: _showAddAddressDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Alamat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}