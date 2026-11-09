import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../ipconfig.dart';
import '../profile/daftar_alamat_page.dart';
import 'riwayat_pickup_page.dart';

// Alias tipe agar kebal error copy-paste kurung bertingkat
typedef AddressMap = Map<String, dynamic>;

// Model spesifikasi armada
class FleetSpec {
  final String type;
  final String title;
  final IconData icon;
  final double maxCapacityKg;
  final String distance;
  final String time;

  const FleetSpec({
    required this.type,
    required this.title,
    required this.icon,
    required this.maxCapacityKg,
    required this.distance,
    required this.time,
  });
}

// Model jenis sampah admin
class WasteTypeItem {
  final int id;
  final String name;
  final String rawName;
  final String co2FactorKg;
  final double pricePerKg;

  WasteTypeItem({
    required this.id,
    required this.name,
    required this.rawName,
    this.co2FactorKg = '2.0',
    required this.pricePerKg,
  });
}

class PickupWastePage extends StatefulWidget {
  const PickupWastePage({super.key});

  @override
  State<PickupWastePage> createState() => _PickupWastePageState();
}

class _PickupWastePageState extends State<PickupWastePage> {
  // Palet Warna Kuning Gojek EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  AddressMap? _selectedAddress;
  bool _isLoadingAddress = true;
  double _estimatedWeight = 15.0;

  bool _isLoadingWasteTypes = true;
  List<WasteTypeItem> _availableWasteTypes = [];
  final Set<int> _selectedWasteTypeIds = {};

  final List<FleetSpec> _fleetSpecs = const [
    FleetSpec(
      type: 'MOTORCYCLE',
      title: 'Motor Roda 3',
      icon: Icons.two_wheeler,
      maxCapacityKg: 35.0,
      distance: '1.2 Km',
      time: '5 menit',
    ),
    FleetSpec(
      type: 'CART',
      title: 'Gerobak Motor',
      icon: Icons.shopping_cart_outlined,
      maxCapacityKg: 150.0,
      distance: '1.8 Km',
      time: '8 menit',
    ),
    FleetSpec(
      type: 'CAR',
      title: 'Mobil Pickup',
      icon: Icons.local_shipping,
      maxCapacityKg: 600.0,
      distance: '2.5 Km',
      time: '12 menit',
    ),
  ];

  int _selectedFleetIndex = 0;
  String selectedDestination = "container"; // 'container' atau 'enterprise'
  int _selectedMachineIndex = 0;
  int? _selectedMachineId;

  bool loading = false;
  bool isFetchingMachines = true;
  List<dynamic> activeMachines = [];

  final TextEditingController _notesController = TextEditingController();

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0;
    final double dLat = (lat2 - lat1) * (math.pi / 180.0);
    final double dLon = (lon2 - lon1) * (math.pi / 180.0);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double get _currentAvgPricePerKg {
    if (_selectedWasteTypeIds.isEmpty) return 500.0;
    final selected = _availableWasteTypes.where((t) => _selectedWasteTypeIds.contains(t.id));
    if (selected.isEmpty) return 500.0;
    double sum = 0.0;
    for (var item in selected) {
      sum += item.pricePerKg;
    }
    return sum / selected.length;
  }

  double get _estimatedEarnings => _estimatedWeight * _currentAvgPricePerKg;

  @override
  void initState() {
    super.initState();
    _fetchAddressesFromDb();
    _fetchWasteTypesFromDb();
    _loadInitialMachines();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // 1. Ambil alamat aktif dari Database
  Future<void> _fetchAddressesFromDb() async {
    setState(() => _isLoadingAddress = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getUserAddresses),
        headers: ApiConfig.headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List list = decoded['data'] ?? [];
        if (list.isNotEmpty) {
          final defaultAddr = list.firstWhere(
            (a) => a['isDefault'] == true,
            orElse: () => list.first,
          );
          setState(() {
            _selectedAddress = Map<String, dynamic>.from(defaultAddr);
          });
          _autoSelectClosestMachine();
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat alamat dari DB: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  // 2. Ambil Master Jenis Sampah & Harga Admin Aktif dari Backend
  Future<void> _fetchWasteTypesFromDb() async {
    setState(() => _isLoadingWasteTypes = true);
    try {
      var res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/jobs/materials'),
        headers: ApiConfig.headers,
      );

      if (res.statusCode != 200) {
        res = await http.get(
          Uri.parse(ApiConfig.getWasteTypes),
          headers: ApiConfig.headers,
        );
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List list = decoded['data'] is List ? decoded['data'] : [];

        if (list.isNotEmpty) {
          setState(() {
            _availableWasteTypes = list.map((item) {
              final String rawName = (item['name'] ?? 'Material').toString();

              double price = 500.0;
              if (item['pricePerKg'] != null) {
                price = double.tryParse(item['pricePerKg'].toString()) ?? 500.0;
              } else if (item['wasteType'] != null && item['wasteType']['prices'] is List) {
                final pricesList = item['wasteType']['prices'] as List;
                if (pricesList.isNotEmpty && pricesList[0]['pricePerKg'] != null) {
                  price = double.tryParse(pricesList[0]['pricePerKg'].toString()) ?? 500.0;
                }
              }

              return WasteTypeItem(
                id: int.tryParse(item['id'].toString()) ?? 1,
                name: rawName,
                rawName: rawName,
                co2FactorKg: (item['co2FactorKg'] ?? '2.0').toString(),
                pricePerKg: price,
              );
            }).toList();

            if (_availableWasteTypes.isNotEmpty && _selectedWasteTypeIds.isEmpty) {
              _selectedWasteTypeIds.add(_availableWasteTypes.first.id);
            }
          });
          return;
        }
      }

      _setDefaultWasteTypes();
    } catch (e) {
      _setDefaultWasteTypes();
    } finally {
      if (mounted) setState(() => _isLoadingWasteTypes = false);
    }
  }

  void _setDefaultWasteTypes() {
    setState(() {
      _availableWasteTypes = [
        WasteTypeItem(id: 1, name: 'PET (Botol Bening)', rawName: 'plastic', pricePerKg: 500.0),
        WasteTypeItem(id: 2, name: 'Kardus & Kertas', rawName: 'paper', pricePerKg: 500.0),
        WasteTypeItem(id: 3, name: 'Kaleng Aluminium', rawName: 'metal', pricePerKg: 500.0),
        WasteTypeItem(id: 4, name: 'Botol & Pecahan Kaca', rawName: 'glass', pricePerKg: 500.0),
      ];
      _selectedWasteTypeIds.add(1);
    });
  }

  // 3. Ambil data Smart Container dari Database
  Future<void> _loadInitialMachines() async {
    setState(() => isFetchingMachines = true);
    try {
      final machineUri = Uri.parse(ApiConfig.getPublicMachines);
      final machineRes = await http.get(machineUri, headers: ApiConfig.headers);
      if (machineRes.statusCode == 200) {
        final machineData = jsonDecode(machineRes.body);
        if (machineData['data'] is List && (machineData['data'] as List).isNotEmpty) {
          activeMachines = List.from(machineData['data']);
          _autoSelectClosestMachine();
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat data mesin: $e");
    } finally {
      if (mounted) setState(() => isFetchingMachines = false);
    }
  }

  // Otomatis prioritaskan mesin terdekat dari koordinat GPS alamat pemesan
  void _autoSelectClosestMachine() {
    if (activeMachines.isEmpty) return;

    double? userLat;
    double? userLng;

    if (_selectedAddress != null) {
      userLat = double.tryParse((_selectedAddress!['latitude'] ?? '').toString());
      userLng = double.tryParse((_selectedAddress!['longitude'] ?? '').toString());
    }

    int bestIndex = 0;

    if (userLat != null && userLng != null && userLat != 0 && userLng != 0) {
      double minDistance = double.infinity;
      for (int i = 0; i < activeMachines.length; i++) {
        final m = activeMachines[i];
        final double? mLat = double.tryParse((m['latitude'] ?? '').toString());
        final double? mLng = double.tryParse((m['longitude'] ?? '').toString());

        if (mLat != null && mLng != null && mLat != 0 && mLng != 0) {
          final double dist = _calculateDistanceKm(userLat, userLng, mLat, mLng);
          if (dist < minDistance) {
            minDistance = dist;
            bestIndex = i;
          }
        }
      }
    }

    setState(() {
      _selectedMachineIndex = bestIndex;
      _selectedMachineId = int.tryParse(activeMachines[bestIndex]['id'].toString());
    });
  }

  void _onWeightChanged(double newWeight) {
    setState(() {
      _estimatedWeight = newWeight.clamp(1.0, 600.0);
      _autoAdjustFleet();
    });
  }

  void _autoAdjustFleet() {
    final currentFleet = _fleetSpecs[_selectedFleetIndex];
    if (_estimatedWeight > currentFleet.maxCapacityKg) {
      final suitableIndex = _fleetSpecs.indexWhere((f) => _estimatedWeight <= f.maxCapacityKg);
      if (suitableIndex != -1) {
        _selectedFleetIndex = suitableIndex;
      }
    }
  }

  void _openAddressSelector() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DaftarAlamatPage(isSelecting: true)),
    );

    if (selected != null && selected is Map) {
      setState(() {
        _selectedAddress = Map<String, dynamic>.from(selected);
      });
      _autoSelectClosestMachine();
    }
  }

  void _openMachineSelector() {
    if (activeMachines.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Pilih Smart Container Tujuan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: brandYellow.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                            child: Text("${activeMachines.length} Mesin Aktif", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: activeMachines.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = activeMachines[i];
                          final int mId = int.tryParse(m['id'].toString()) ?? 0;
                          final bool isSelected = _selectedMachineId != null ? (_selectedMachineId == mId) : (_selectedMachineIndex == i);

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? brandYellow.withOpacity(0.3) : const Color(0xFFF4F6F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.inventory_2_outlined, color: isSelected ? textDark : Colors.grey, size: 24),
                            ),
                            title: Text(m['name'] ?? 'Smart Container', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
                            subtitle: Text("${m['placeName'] ?? 'Kota Bandung'} • Terisi ${m['fillPercentage'] ?? 0}%", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? textDark : Colors.grey.shade400),
                            onTap: () {
                              setModalState(() {
                                _selectedMachineIndex = i;
                                _selectedMachineId = mId;
                              });
                              setState(() {
                                _selectedMachineIndex = i;
                                _selectedMachineId = mId;
                                selectedDestination = "container";
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 4. Kirim pesanan penjemputan ke Backend (Payload & Logic Utuh Sesuai Integrasi)
  Future<void> _orderPickup() async {
    if (!ApiConfig.hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login terlebih dahulu"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih atau tambahkan alamat penjemputan terlebih dahulu"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedWasteTypeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih minimal satu jenis sampah yang ingin disetor!"), backgroundColor: Colors.red),
      );
      return;
    }

    final selectedFleet = _fleetSpecs[_selectedFleetIndex];
    if (_estimatedWeight > selectedFleet.maxCapacityKg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Muatan ${_estimatedWeight.toStringAsFixed(0)} kg melebihi kapasitas ${selectedFleet.title}."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      String destinationTitle = "Smart Container";
      int? targetMachineId;

      if (selectedDestination == "container") {
        if (activeMachines.isNotEmpty) {
          final targetMachine = (_selectedMachineId != null)
              ? activeMachines.firstWhere((m) => int.tryParse(m['id'].toString()) == _selectedMachineId, orElse: () => activeMachines[_selectedMachineIndex])
              : activeMachines[_selectedMachineIndex];

          final String mName = targetMachine['name'] ?? targetMachine['placeName'] ?? "Smart Container";
          destinationTitle = "Smart Container ($mName)";
          targetMachineId = int.tryParse(targetMachine['id'].toString());
        } else {
          destinationTitle = "Smart Container (Umum)";
        }
      } else {
        destinationTitle = "EcoCash Enterprise Partner (Recycler)";
      }

      final String finalAddress = (_selectedAddress!['detail'] ?? _selectedAddress!['address'] ?? 'Alamat Warga').toString();

      final List<String> selectedNames = _availableWasteTypes
          .where((t) => _selectedWasteTypeIds.contains(t.id))
          .map((t) => t.name)
          .toList();

      final String materialCategoryString = selectedNames.join(', ');

      // Payload JSON dikirim utuh tanpa mengubah nama kolom atau integrasi backend
      final payload = {
        "title": "Penjemputan Sampah - Warga",
        "addressId": _selectedAddress?['id'],
        "address": finalAddress,
        "notes": "${_notesController.text.trim()} (Armada: ${selectedFleet.title} | Tujuan: $destinationTitle)",
        "estimatedWeight": _estimatedWeight,
        "vehicleType": selectedFleet.type,
        "materialCategory": materialCategoryString,
        "wasteTypeIds": _selectedWasteTypeIds.toList(),
        if (targetMachineId != null) "machineId": targetMachineId,
        if (targetMachineId != null) "targetMachineId": targetMachineId,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.createPickupOrder),
        headers: ApiConfig.headers,
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || (response.statusCode == 200 && data['success'] == true)) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiwayatPickupPage()),
        );
      } else {
        if (!mounted) return;
        final String errorMsg = data['message'] ?? 'Gagal membuat pesanan penjemputan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan jaringan: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildAddressCard(),
                  const SizedBox(height: 16),
                  _buildWasteTypeSection(),
                  const SizedBox(height: 16),
                  _buildWeightControlSection(),
                  const SizedBox(height: 20),
                  _sectionTitle("Pilihan Armada Penjemput"),
                  _buildSmartFleetList(),
                  const SizedBox(height: 24),
                  _sectionTitle("Tujuan Penyetoran"),
                  _buildDestinationOptions(),
                  const SizedBox(height: 16),
                  _buildNotesInput(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: textDark),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Jemput Sampah", style: TextStyle(color: textDark, fontSize: 21, fontWeight: FontWeight.w900)),
                    Text("Alokasi armada sesuai kapasitas muatan", style: TextStyle(color: textDark, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Riwayat Pesanan',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RiwayatPickupPage())),
                icon: const Icon(Icons.history_rounded, color: textDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: _isLoadingAddress
          ? const Center(child: CircularProgressIndicator(color: primaryNavy))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.location_on_rounded, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 8),
                        Text('Alamat Penjemputan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                      ],
                    ),
                    InkWell(
                      onTap: _openAddressSelector,
                      child: const Text('Ganti Alamat', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedAddress != null
                      ? (_selectedAddress!['detail'] ?? _selectedAddress!['address'] ?? 'Alamat belum diatur')
                      : 'Belum ada alamat tersimpan di database.',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
    );
  }

  Widget _buildWasteTypeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kategori Jenis Sampah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark)),
              Text('${_selectedWasteTypeIds.length} Dipilih', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableWasteTypes.map((type) {
              final bool isSelected = _selectedWasteTypeIds.contains(type.id);
              return FilterChip(
                label: Text('${type.name} (@${_currencyFormat.format(type.pricePerKg)}/kg)'),
                selected: isSelected,
                selectedColor: brandYellow,
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: textDark,
                ),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedWasteTypeIds.add(type.id);
                    } else if (_selectedWasteTypeIds.length > 1) {
                      _selectedWasteTypeIds.remove(type.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightControlSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Berat Sampah yang Disetor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: brandYellow.withOpacity(0.35), borderRadius: BorderRadius.circular(10)),
                child: Text('${_estimatedWeight.toStringAsFixed(1)} Kg', style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: textDark,
              thumbColor: brandYellow,
              inactiveTrackColor: Colors.grey.shade200,
            ),
            child: Slider(
              value: _estimatedWeight,
              min: 1.0,
              max: 300.0,
              divisions: 299,
              onChanged: _onWeightChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimasi Saldo Diterima', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_currencyFormat.format(_estimatedEarnings), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ecoGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
    );
  }

  Widget _buildSmartFleetList() {
    return Column(
      children: List.generate(_fleetSpecs.length, (index) {
        final fleet = _fleetSpecs[index];
        final bool isSelected = _selectedFleetIndex == index;

        return GestureDetector(
          onTap: () => setState(() => _selectedFleetIndex = index),
          child: Container(
            margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? textDark : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isSelected ? brandYellow : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: Icon(fleet.icon, color: textDark, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fleet.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
                      Text('Kapasitas: ${fleet.maxCapacityKg.toInt()} Kg • Tiba ~${fleet.time}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? textDark : Colors.grey),
              ],
            ),
          ),
        );
      }),
    );
  }

  // Tampilkan Nama Mesin Aktual & Rincian Sesuai yang Dipilih
  Widget _buildDestinationOptions() {
    final Map<String, dynamic>? currentMachine = (activeMachines.isNotEmpty)
        ? ((_selectedMachineId != null)
            ? activeMachines.firstWhere((m) => int.tryParse(m['id'].toString()) == _selectedMachineId, orElse: () => activeMachines[_selectedMachineIndex])
            : activeMachines[_selectedMachineIndex])
        : null;

    final String machineTitle = currentMachine != null
        ? (currentMachine['name'] ?? "Smart Container")
        : "Smart Container EcoCash";

    final int fillPct = currentMachine != null ? (currentMachine['fillPercentage'] ?? 0) : 0;
    final bool isFull = fillPct >= 80;
    final String areaInfo = currentMachine != null ? (currentMachine['placeName'] ?? currentMachine['address'] ?? '') : '';

    return Column(
      children: [
        _destinationCard(
          "container",
          Icons.inventory_2_outlined,
          machineTitle,
          isFull
              ? "Kapasitas mesin hampir penuh ($fillPct%) • $areaInfo"
              : "Terisi $fillPct% • $areaInfo",
          onActionTap: activeMachines.length > 1 ? _openMachineSelector : null,
          actionLabel: activeMachines.length > 1
              ? "Ganti Titik (${activeMachines.length} Mesin Tersedia)"
              : null,
        ),
        _destinationCard(
          "enterprise",
          Icons.business_outlined,
          "Mitra Daur Ulang (TPS/Pabrik)",
          "Siap menampung kapasitas besar tanpa batas jangkauan kontainer",
        ),
      ],
    );
  }

  Widget _destinationCard(
    String value,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onActionTap,
    String? actionLabel,
  }) {
    final bool active = selectedDestination == value;

    return GestureDetector(
      onTap: () => setState(() => selectedDestination = value),
      child: Container(
        margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? textDark : Colors.transparent, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: textDark, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(active ? Icons.check_circle : Icons.circle_outlined, color: active ? textDark : Colors.grey),
              ],
            ),
            if (active && onActionTap != null && actionLabel != null) ...[
              const Divider(height: 16),
              InkWell(
                onTap: onActionTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textDark)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 16, color: textDark),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: _notesController,
        decoration: const InputDecoration(
          isDense: true,
          labelText: "Instruksi Penjemputan (Opsional)",
          hintText: "Contoh: Sampah sudah diikat karung di teras",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _bottomButton() {
    final selectedFleet = _fleetSpecs[_selectedFleetIndex];
    final bool isOverweight = _estimatedWeight > selectedFleet.maxCapacityKg;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (loading || isOverweight) ? null : _orderPickup,
            style: ElevatedButton.styleFrom(
              backgroundColor: isOverweight ? Colors.grey : brandYellow,
              foregroundColor: textDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: textDark, strokeWidth: 2))
                : Text(
                    isOverweight ? "Muatan Melebihi Kapasitas Armada" : "Pesan ${selectedFleet.title} (~${_currencyFormat.format(_estimatedEarnings)})",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
      ),
    );
  }
}