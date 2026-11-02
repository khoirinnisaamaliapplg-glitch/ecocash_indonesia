import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../ipconfig.dart';
import '../profile/daftar_alamat_page.dart';
import 'riwayat_pickup_page.dart';

// --- MODEL DATA SPESIFIKASI ARMADA FLEET ---
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

// --- MODEL DATA MASTER JENIS SAMPAH & HARGA ADMIN ---
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
  final Color primary = const Color(0xff0BCFD1);

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Alamat aktif dari Database
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddress = true;

  // Bobot Sampah yang Diinput
  double _estimatedWeight = 15.0;

  // Master Jenis Sampah dari Database Admin
  bool _isLoadingWasteTypes = true;
  List<WasteTypeItem> _availableWasteTypes = [];
  final Set<int> _selectedWasteTypeIds = {};

  // Spesifikasi Kapasitas Resmi Armada EcoCash
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
  int? _selectedMachineId; // ID unik mesin terpilih

  bool loading = false;
  bool isFetchingMachines = true;
  List<dynamic> activeMachines = [];

  final TextEditingController _notesController = TextEditingController();

  // Hitung jarak Haversine (Km) antara dua titik koordinat
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

  // Hitung rata-rata harga per kg dari material terpilih
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
              } else if (item['prices'] is List && (item['prices'] as List).isNotEmpty) {
                price = double.tryParse(item['prices'][0]['pricePerKg'].toString()) ?? 500.0;
              }

              return WasteTypeItem(
                id: int.tryParse(item['id'].toString()) ?? 1,
                name: _formatWasteTypeName(rawName),
                rawName: rawName,
                co2FactorKg: (item['co2FactorKg'] ?? item['wasteType']?['co2FactorKg'] ?? '2.0').toString(),
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
      debugPrint("Gagal memuat jenis sampah: $e");
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

  String _formatWasteTypeName(String raw) {
    return raw.isNotEmpty ? raw : 'Material Daur Ulang';
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

  // Logika Otomatis: Memilih Mesin Paling Dekat dari Koordinat / Alamat Warga
  void _autoSelectClosestMachine() {
    if (activeMachines.isEmpty) return;

    double? userLat;
    double? userLng;

    if (_selectedAddress != null) {
      userLat = double.tryParse((_selectedAddress!['latitude'] ?? '').toString());
      userLng = double.tryParse((_selectedAddress!['longitude'] ?? '').toString());
    }

    int bestIndex = 0;

    // Prioritas 1: Hitung jarak geometris GPS jika koordinat tersedia
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
    } else if (_selectedAddress != null) {
      // Prioritas 2: Fallback pencocokan kata daerah/kota pada detail alamat
      final String fullAddr = [
        _selectedAddress!['city'] ?? '',
        _selectedAddress!['district'] ?? '',
        _selectedAddress!['detail'] ?? '',
        _selectedAddress!['address'] ?? '',
      ].join(' ').toLowerCase();

      for (int i = 0; i < activeMachines.length; i++) {
        final m = activeMachines[i];
        final String mName = (m['name'] ?? '').toString().toLowerCase();
        final String mPlace = (m['placeName'] ?? '').toString().toLowerCase();
        final String mAddr = (m['address'] ?? '').toString().toLowerCase();

        final words = fullAddr.split(RegExp(r'\s+')).where((w) => w.length >= 4);
        bool match = false;
        for (final w in words) {
          if (mName.contains(w) || mPlace.contains(w) || mAddr.contains(w)) {
            bestIndex = i;
            match = true;
            break;
          }
        }
        if (match) break;
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
    final double maxCap = currentFleet.maxCapacityKg;

    if (_estimatedWeight > maxCap) {
      final suitableIndex = _fleetSpecs.indexWhere(
        (f) => _estimatedWeight <= f.maxCapacityKg,
      );
      if (suitableIndex != -1) {
        _selectedFleetIndex = suitableIndex;
      }
    }
  }

  void _openAddressSelector() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DaftarAlamatPage(isSelecting: true),
      ),
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

    double? userLat;
    double? userLng;
    if (_selectedAddress != null) {
      userLat = double.tryParse((_selectedAddress!['latitude'] ?? '').toString());
      userLng = double.tryParse((_selectedAddress!['longitude'] ?? '').toString());
    }

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Pilih Smart Container Tujuan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text("${activeMachines.length} Mesin Aktif", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
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

                          final int fill = m['fillPercentage'] ?? 0;
                          final String area = m['placeName'] ?? m['address'] ?? 'Kota Bandung';
                          final String code = m['machineCode'] ?? 'MCH-$i';

                          // Format jarak jika koordinat kedua titik ada
                          String distanceInfo = '';
                          final double? mLat = double.tryParse((m['latitude'] ?? '').toString());
                          final double? mLng = double.tryParse((m['longitude'] ?? '').toString());
                          if (userLat != null && userLng != null && mLat != null && mLng != null && userLat != 0 && mLat != 0) {
                            final double dist = _calculateDistanceKm(userLat, userLng, mLat, mLng);
                            distanceInfo = ' • 📍 ${dist.toStringAsFixed(1)} Km';
                          }

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? primary.withOpacity(0.15) : const Color(0xFFF4F6F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.inventory_2_outlined, color: isSelected ? primary : Colors.grey, size: 24),
                            ),
                            title: Row(
                              children: [
                                Text(m['name'] ?? 'Smart Container', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                  child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                                ),
                              ],
                            ),
                            subtitle: Text("$area • Terisi $fill%$distanceInfo", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? primary : Colors.grey.shade400),
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

  // 4. Kirim pesanan penjemputan dengan machineId aktual ke Backend
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
    final double maxCap = selectedFleet.maxCapacityKg;

    if (_estimatedWeight > maxCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Muatan ${_estimatedWeight.toStringAsFixed(0)} kg melebihi kapasitas ${selectedFleet.title}. Harap pilih armada yang lebih besar."),
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text("Pesanan Terkirim!"),
              ],
            ),
            content: Text(
              "Permintaan jemput sampah ($materialCategoryString) berhasil dibuat. Estimasi bagi hasil: ${_currencyFormat.format(_estimatedEarnings)}.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("Ke Beranda", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const RiwayatPickupPage()),
                  );
                },
                child: const Text("Pantau Status & Chat Driver", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        final String errorMsg = data['message'] ?? 'Gagal membuat pesanan penjemputan';
        final String? errorCode = data['code'];

        if (errorCode == 'OUT_OF_SERVICE_AREA' || errorMsg.contains('terlalu jauh')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.location_off, color: Colors.redAccent, size: 26),
                  SizedBox(width: 8),
                  Text("Di Luar Jangkauan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                "$errorMsg\n\nTips: Anda bisa mengalihkan tujuan penyetoran ke Mitra Daur Ulang (TPS/Pabrik) yang siap menampung sampah tanpa batas jangkauan kontainer.",
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Tutup", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      selectedDestination = "enterprise";
                    });
                  },
                  child: const Text("Pilih Mitra Daur Ulang", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xffF7F8F3),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: size.height * .15),
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
                  _sectionTitle("Pilih Tujuan Penyetoran"),
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
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage("assets/bg.png"), fit: BoxFit.cover),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(.2), shape: BoxShape.circle),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Jemput Sampah", style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                    SizedBox(height: 3),
                    Text("Alokasi armada sesuai kapasitas muatan", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(.2), shape: BoxShape.circle),
                child: IconButton(
                  tooltip: 'Riwayat Pesanan',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RiwayatPickupPage())),
                  icon: const Icon(Icons.history, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: _isLoadingAddress
          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedAddress?['label'] ?? 'Pilih Alamat',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _openAddressSelector,
                      child: Text('Ganti Alamat', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kategori Jenis Sampah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (_isLoadingWasteTypes)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Text(
                  '${_selectedWasteTypeIds.length} Dipilih',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Harga per kg diatur dinamis oleh sistem. Pilih jenis sampah yang akan disetor:',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableWasteTypes.map((type) {
              final int id = type.id;
              final bool isSelected = _selectedWasteTypeIds.contains(id);
              final double price = type.pricePerKg;

              return FilterChip(
                label: Text('${type.name} (@${_currencyFormat.format(price)}/kg)'),
                selected: isSelected,
                selectedColor: primary.withOpacity(0.18),
                checkmarkColor: primary,
                backgroundColor: const Color(0xFFF4F6F8),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? primary : Colors.black87,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? primary : Colors.grey.shade300),
                ),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedWasteTypeIds.add(id);
                    } else {
                      if (_selectedWasteTypeIds.length > 1) {
                        _selectedWasteTypeIds.remove(id);
                      }
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Berat Sampah yang Disetor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${_estimatedWeight.toStringAsFixed(1)} Kg',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [10.0, 25.0, 50.0, 100.0, 200.0].map((w) {
              final bool isSelected = (_estimatedWeight - w).abs() < 0.1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onWeightChanged(w),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primary : const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${w.toInt()}kg',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primary,
              thumbColor: primary,
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
          const Divider(height: 20),

          // Pratinjau Estimasi Saldo Masuk Warga
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimasi Saldo Diterima', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    'Rate Rata-rata: ${_currencyFormat.format(_currentAvgPricePerKg)}/kg',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Text(
                _currencyFormat.format(_estimatedEarnings),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSmartFleetList() {
    return Column(
      children: List.generate(_fleetSpecs.length, (index) {
        final fleet = _fleetSpecs[index];
        final double maxCap = fleet.maxCapacityKg;
        final bool isCapable = _estimatedWeight <= maxCap;
        final bool isSelected = _selectedFleetIndex == index;

        return GestureDetector(
          onTap: isCapable
              ? () {
                  setState(() => _selectedFleetIndex = index);
                }
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Armada ${fleet.title} tidak muat! Maksimal kapasitas hanya ${maxCap.toInt()} kg.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isCapable ? 1.0 : 0.40,
            child: Container(
              margin: const EdgeInsets.only(top: 10, left: 20, right: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected && isCapable ? primary : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected && isCapable ? primary.withOpacity(.18) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(fleet.icon, color: isCapable ? primary : Colors.grey, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(fleet.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            if (!isCapable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text('Kelebihan Beban', style: TextStyle(color: Colors.red.shade700, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Kapasitas Maksimal: ${maxCap.toInt()} Kg', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '📍 Radius ${fleet.distance} • Tiba ~${fleet.time}',
                          style: TextStyle(
                            color: isSelected && isCapable ? primary : Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected && isCapable ? Icons.check_circle : (isCapable ? Icons.radio_button_unchecked : Icons.lock_outline),
                    color: isSelected && isCapable ? primary : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDestinationOptions() {
    if (isFetchingMachines) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

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
    bool active = selectedDestination == value;
    return GestureDetector(
      onTap: () => setState(() => selectedDestination = value),
      child: Container(
        margin: const EdgeInsets.only(top: 10, left: 20, right: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? primary : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: active ? primary : Colors.grey, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(active ? Icons.check_circle : Icons.circle_outlined, color: active ? primary : Colors.grey),
              ],
            ),
            if (active && onActionTap != null && actionLabel != null) ...[
              const Divider(height: 18),
              InkWell(
                onTap: onActionTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: primary),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: _notesController,
        decoration: const InputDecoration(
          isDense: true,
          labelText: "Instruksi Khusus untuk Penjemput (Opsional)",
          hintText: "Contoh: Sampah sudah diikat karung di teras",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _bottomButton() {
    final selectedFleet = _fleetSpecs[_selectedFleetIndex];
    final double maxCap = selectedFleet.maxCapacityKg;
    final bool isOverweight = _estimatedWeight > maxCap;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (loading || isOverweight) ? null : _orderPickup,
            style: ElevatedButton.styleFrom(
              backgroundColor: isOverweight ? Colors.grey : primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    isOverweight ? "Muatan Melebihi Kapasitas Armada" : "Pesan ${selectedFleet.title} (~${_currencyFormat.format(_estimatedEarnings)})",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}