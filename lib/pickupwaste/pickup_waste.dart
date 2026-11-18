import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../ipconfig.dart';
import '../profile/daftar_alamat_page.dart';
import 'riwayat_pickup_page.dart';

typedef AddressMap = Map<String, dynamic>;

class FleetSpec {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final double maxCapacityKg;
  final String distance;
  final String time;

  const FleetSpec({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.maxCapacityKg,
    required this.distance,
    required this.time,
  });
}

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
  // Palet Warna Modern EcoCash
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color brandYellowSoft = Color(0xFFFFF9C4);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF059669);
  static const Color ecoGreenSoft = Color(0xFFECFDF5);
  static const Color surfaceBg = Color(0xFFF3F4F6);
  static const Color borderSubtle = Color(0xFFE5E7EB);

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
  String? _appliedAreaName;

  final List<FleetSpec> _fleetSpecs = const [
    FleetSpec(
      type: 'MOTORCYCLE',
      title: 'Motor Roda 3',
      subtitle: 'Gesit untuk gang & rumah tangga',
      icon: Icons.two_wheeler_rounded,
      maxCapacityKg: 35.0,
      distance: '1.2 Km',
      time: '5 mnt',
    ),
    FleetSpec(
      type: 'CART',
      title: 'Gerobak Motor',
      subtitle: 'Ideal untuk muatan menengah',
      icon: Icons.moped_rounded,
      maxCapacityKg: 150.0,
      distance: '1.8 Km',
      time: '8 mnt',
    ),
    FleetSpec(
      type: 'CAR',
      title: 'Mobil Pickup',
      subtitle: 'Kapasitas besar & sampah komersial',
      icon: Icons.local_shipping_rounded,
      maxCapacityKg: 600.0,
      distance: '2.5 Km',
      time: '12 mnt',
    ),
  ];

  int _selectedFleetIndex = 0;
  String selectedDestination = "container";
  int _selectedMachineIndex = 0;
  int? _selectedMachineId;

  bool loading = false;
  bool isFetchingMachines = true;
  List<dynamic> activeMachines = [];

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(text: '15');

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
    _initData();
  }

  Future<void> _initData() async {
    await _fetchAddressesFromDb();
    await Future.wait([
      _fetchWasteTypesFromDb(),
      _loadInitialMachines(),
    ]);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

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
          if (mounted) {
            setState(() {
              _selectedAddress = Map<String, dynamic>.from(defaultAddr);
            });
          }
          _autoSelectClosestMachine();
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat alamat dari DB: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _fetchWasteTypesFromDb() async {
    if (mounted) setState(() => _isLoadingWasteTypes = true);
    try {
      final queryParams = <String, String>{};
      if (_selectedAddress != null) {
        if (_selectedAddress!['id'] != null) {
          queryParams['addressId'] = _selectedAddress!['id'].toString();
        }
        if (_selectedAddress!['areaId'] != null) {
          queryParams['areaId'] = _selectedAddress!['areaId'].toString();
        }
        if (_selectedAddress!['city'] != null &&
            _selectedAddress!['city'].toString().trim().isNotEmpty) {
          queryParams['city'] = _selectedAddress!['city'].toString().trim();
        }
      }

      final materialsUri = Uri.parse('${ApiConfig.baseUrl}/jobs/materials')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      var res = await http.get(
        materialsUri,
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

        if (list.isNotEmpty && mounted) {
          final firstAreaName =
              list.first is Map ? list.first['appliedAreaName']?.toString() : null;
          setState(() {
            _appliedAreaName = (firstAreaName != null && firstAreaName.isNotEmpty)
                ? firstAreaName
                : _selectedAddress?['city']?.toString();

            _availableWasteTypes = list.map((item) {
              final String rawName = (item['name'] ?? 'Material').toString();

              double price = 500.0;
              if (item['pricePerKg'] != null) {
                price = double.tryParse(item['pricePerKg'].toString()) ?? 500.0;
              } else if (item['wasteType'] != null &&
                  item['wasteType']['prices'] is List) {
                final pricesList = item['wasteType']['prices'] as List;
                if (pricesList.isNotEmpty &&
                    pricesList[0]['pricePerKg'] != null) {
                  price = double.tryParse(
                          pricesList[0]['pricePerKg'].toString()) ??
                      500.0;
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

            if (_availableWasteTypes.isNotEmpty &&
                _selectedWasteTypeIds.isEmpty) {
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
    if (!mounted) return;
    setState(() {
      _availableWasteTypes = [
        WasteTypeItem(id: 1, name: 'PET (Botol Bening)', rawName: 'plastic', pricePerKg: 500.0),
        WasteTypeItem(id: 2, name: 'Kardus & Kertas', rawName: 'paper', pricePerKg: 500.0),
        WasteTypeItem(id: 3, name: 'Kaleng Aluminium', rawName: 'metal', pricePerKg: 500.0),
        WasteTypeItem(id: 4, name: 'Botol & Pecahan Kaca', rawName: 'glass', pricePerKg: 500.0),
      ];
      if (_selectedWasteTypeIds.isEmpty) {
        _selectedWasteTypeIds.add(1);
      }
    });
  }

  Future<void> _loadInitialMachines() async {
    if (mounted) setState(() => isFetchingMachines = true);
    try {
      final machineUri = Uri.parse(ApiConfig.getPublicMachines);
      final machineRes = await http.get(machineUri, headers: ApiConfig.headers);
      if (machineRes.statusCode == 200) {
        final machineData = jsonDecode(machineRes.body);
        if (machineData['data'] is List &&
            (machineData['data'] as List).isNotEmpty) {
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

  void _autoSelectClosestMachine() {
    if (activeMachines.isEmpty || !mounted) return;

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

  String _formatWeightInput(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return double.parse(value.toStringAsFixed(2)).toString();
  }

  void _onWeightChanged(double newWeight, {bool syncText = true}) {
    final clamped = newWeight.clamp(0.5, 600.0);
    setState(() {
      _estimatedWeight = clamped;
      _autoAdjustFleet();
    });
    if (syncText) {
      final formatted = _formatWeightInput(clamped);
      if (_weightController.text != formatted) {
        _weightController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  void _onManualWeightTyped(String raw) {
    final normalized = raw.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return;
    final parsed = double.tryParse(normalized);
    if (parsed != null && parsed >= 0.5) {
      _onWeightChanged(parsed, syncText: false);
    }
  }

  void _autoAdjustFleet() {
    final currentFleet = _fleetSpecs[_selectedFleetIndex];
    if (_estimatedWeight > currentFleet.maxCapacityKg) {
      final suitableIndex =
          _fleetSpecs.indexWhere((f) => _estimatedWeight <= f.maxCapacityKg);
      if (suitableIndex != -1) {
        _selectedFleetIndex = suitableIndex;
      }
    }
  }

  void _openAddressSelector() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const DaftarAlamatPage(isSelecting: true)),
    );

    if (selected != null && selected is Map) {
      setState(() {
        _selectedAddress = Map<String, dynamic>.from(selected);
      });
      _autoSelectClosestMachine();
      await _fetchWasteTypesFromDb();
    }
  }

  void _openMachineSelector() {
    if (activeMachines.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Pilih Smart Container",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: brandYellowSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${activeMachines.length} Aktif",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: activeMachines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final m = activeMachines[i];
                          final int mId =
                              int.tryParse(m['id'].toString()) ?? 0;
                          final bool isSelected = _selectedMachineId != null
                              ? (_selectedMachineId == mId)
                              : (_selectedMachineIndex == i);

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
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
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? brandYellowSoft.withValues(alpha: 0.5)
                                    : surfaceBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? textDark : borderSubtle,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? brandYellow
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_rounded,
                                      color: textDark,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['name'] ?? 'Smart Container',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${m['placeName'] ?? 'Lokasi Mesin'} • Terisi ${m['fillPercentage'] ?? 0}%",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? textDark : textMuted,
                                  ),
                                ],
                              ),
                            ),
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

  Future<void> _orderPickup() async {
    if (!ApiConfig.hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Silakan login terlebih dahulu"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih atau tambahkan alamat penjemputan terlebih dahulu"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedWasteTypeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih minimal satu jenis sampah yang ingin disetor!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedFleet = _fleetSpecs[_selectedFleetIndex];
    if (_estimatedWeight > selectedFleet.maxCapacityKg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Muatan ${_estimatedWeight.toStringAsFixed(0)} kg melebihi kapasitas ${selectedFleet.title}."),
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
              ? activeMachines.firstWhere(
                  (m) => int.tryParse(m['id'].toString()) == _selectedMachineId,
                  orElse: () => activeMachines[_selectedMachineIndex])
              : activeMachines[_selectedMachineIndex];

          final String mName = targetMachine['name'] ??
              targetMachine['placeName'] ??
              "Smart Container";
          destinationTitle = "Smart Container ($mName)";
          targetMachineId = int.tryParse(targetMachine['id'].toString());
        } else {
          destinationTitle = "Smart Container (Umum)";
        }
      } else {
        destinationTitle = "EcoCash Enterprise Partner (Recycler)";
      }

      final String finalAddress = (_selectedAddress!['detail'] ??
              _selectedAddress!['address'] ??
              'Alamat Warga')
          .toString();

      final List<String> selectedNames = _availableWasteTypes
          .where((t) => _selectedWasteTypeIds.contains(t.id))
          .map((t) => t.name)
          .toList();

      final String materialCategoryString = selectedNames.join(', ');

      final payload = {
        "title": "Penjemputan Sampah - Warga",
        "addressId": _selectedAddress?['id'],
        "address": finalAddress,
        "notes":
            "${_notesController.text.trim()} (Armada: ${selectedFleet.title} | Tujuan: $destinationTitle)",
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

      if (response.statusCode == 201 ||
          (response.statusCode == 200 && data['success'] == true)) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiwayatPickupPage()),
        );
      } else {
        if (!mounted) return;
        final String errorMsg =
            data['message'] ?? 'Gagal membuat pesanan penjemputan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan jaringan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  IconData _iconForMaterial(String rawName) {
    final lower = rawName.toLowerCase();
    if (lower.contains('pet') || lower.contains('hdpe') || lower.contains('plastik') || lower.contains('botol')) {
      return Icons.local_drink_rounded;
    }
    if (lower.contains('kardus') || lower.contains('kertas') || lower.contains('paper')) {
      return Icons.inventory_2_rounded;
    }
    if (lower.contains('kaleng') || lower.contains('aluminium') || lower.contains('metal') || lower.contains('besi')) {
      return Icons.settings_suggest_rounded;
    }
    if (lower.contains('kaca') || lower.contains('glass')) {
      return Icons.wine_bar_rounded;
    }
    return Icons.recycling_rounded;
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddressCard(),
                  const SizedBox(height: 16),
                  _buildWasteTypeSection(),
                  const SizedBox(height: 16),
                  _buildWeightControlSection(),
                  const SizedBox(height: 22),
                  _sectionHeader(
                    "Pilihan Armada Penjemput",
                    "Otomatis menyesuaikan berat muatan",
                  ),
                  const SizedBox(height: 10),
                  _buildSmartFleetList(),
                  const SizedBox(height: 22),
                  _sectionHeader(
                    "Tujuan Penyetoran",
                    "Titik drop-off akhir kurir",
                  ),
                  const SizedBox(height: 10),
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
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFEE32), brandYellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 20),
          child: Row(
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_rounded, color: textDark, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Jemput Sampah",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Tarif dinamis sesuai wilayah & armada",
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RiwayatPickupPage()),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: textDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, color: brandYellow, size: 15),
                      SizedBox(width: 5),
                      Text(
                        "Riwayat",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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

  Widget _buildAddressCard() {
    final String label =
        (_selectedAddress?['label'] ?? 'Alamat Utama').toString();
    final String city = (_selectedAddress?['city'] ?? '').toString();
    final String detail = _selectedAddress != null
        ? (_selectedAddress!['detail'] ??
                _selectedAddress!['address'] ??
                'Alamat belum diatur')
            .toString()
        : 'Belum ada alamat tersimpan di database.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _isLoadingAddress
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: primaryNavy),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TITIK PENJEMPUTAN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: textDark,
                                ),
                              ),
                              if (city.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: surfaceBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    city,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: primaryNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openAddressSelector,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                      label: const Text('Ubah'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textDark,
                        side: const BorderSide(color: borderSubtle),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: borderSubtle),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWasteTypeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kategori Jenis Sampah',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: textDark,
                ),
              ),
              _isLoadingWasteTypes
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryNavy,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: brandYellowSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedWasteTypeIds.length} Dipilih',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ),
            ],
          ),
          if (_appliedAreaName != null && _appliedAreaName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ecoGreenSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: ecoGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Tarif Wilayah: $_appliedAreaName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ecoGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 10;
              final double itemWidth = (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _availableWasteTypes.map((type) {
                  final bool isSelected =
                      _selectedWasteTypeIds.contains(type.id);

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_selectedWasteTypeIds.length > 1) {
                            _selectedWasteTypeIds.remove(type.id);
                          }
                        } else {
                          _selectedWasteTypeIds.add(type.id);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: itemWidth,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? brandYellowSoft.withValues(alpha: 0.65)
                            : surfaceBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? textDark : borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? brandYellow
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _iconForMaterial(type.name),
                                  size: 16,
                                  color: textDark,
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 18,
                                color: isSelected ? textDark : Colors.grey.shade400,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            type.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_currencyFormat.format(type.pricePerKg)} / kg',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? ecoGreen : primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeightControlSection() {
    const List<double> presetWeights = [5.0, 15.0, 30.0, 50.0, 100.0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Perkiraan Berat Sampah',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: textDark,
                ),
              ),
              Row(
                children: [
                  _stepperButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _onWeightChanged(_estimatedWeight - 1),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: brandYellowSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: brandYellow),
                    ),
                    child: Text(
                      '${_estimatedWeight.toStringAsFixed(1)} Kg',
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _stepperButton(
                    icon: Icons.add_rounded,
                    onTap: () => _onWeightChanged(_estimatedWeight + 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: textDark,
              thumbColor: brandYellow,
              overlayColor: brandYellow.withValues(alpha: 0.25),
              inactiveTrackColor: Colors.grey.shade200,
              trackHeight: 5,
            ),
            child: Slider(
              value: _estimatedWeight.clamp(0.5, 300.0),
              min: 0.5,
              max: 300.0,
              onChanged: (val) => _onWeightChanged(double.parse(val.toStringAsFixed(1))),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presetWeights.map((w) {
                final bool active = (_estimatedWeight - w).abs() < 0.1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${w.toInt()} Kg'),
                    selected: active,
                    selectedColor: textDark,
                    backgroundColor: surfaceBg,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? brandYellow : textDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: active ? textDark : borderSubtle,
                      ),
                    ),
                    onSelected: (_) => _onWeightChanged(w),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ecoGreenSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimasi Saldo Masuk',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rata-rata ${_currencyFormat.format(_currentAvgPricePerKg)}/kg × ${_estimatedWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ecoGreen,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(_estimatedEarnings),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: ecoGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: surfaceBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderSubtle),
        ),
        child: Icon(icon, size: 16, color: textDark),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSmartFleetList() {
    return Column(
      children: List.generate(_fleetSpecs.length, (index) {
        final fleet = _fleetSpecs[index];
        final bool isSelected = _selectedFleetIndex == index;
        final bool isOverCapacity = _estimatedWeight > fleet.maxCapacityKg;
        final double loadRatio =
            (_estimatedWeight / fleet.maxCapacityKg).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: () => setState(() => _selectedFleetIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? (isOverCapacity ? Colors.red : textDark)
                    : borderSubtle,
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: isSelected ? brandYellow : surfaceBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(fleet.icon, color: textDark, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                fleet.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: surfaceBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '~${fleet.time}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fleet.subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? textDark : Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: loadRatio,
                          minHeight: 5,
                          backgroundColor: Colors.grey.shade200,
                          color: isOverCapacity
                              ? Colors.red
                              : (loadRatio > 0.8 ? Colors.orange : ecoGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isOverCapacity
                          ? 'Melebihi ${fleet.maxCapacityKg.toInt()} Kg'
                          : 'Maks. ${fleet.maxCapacityKg.toInt()} Kg',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOverCapacity ? Colors.red : textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDestinationOptions() {
    if (isFetchingMachines && activeMachines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderSubtle),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: primaryNavy),
          ),
        ),
      );
    }

    final Map<String, dynamic>? currentMachine = (activeMachines.isNotEmpty)
        ? ((_selectedMachineId != null)
            ? activeMachines.firstWhere(
                (m) => int.tryParse(m['id'].toString()) == _selectedMachineId,
                orElse: () => activeMachines[_selectedMachineIndex])
            : activeMachines[_selectedMachineIndex])
        : null;

    final String machineTitle = currentMachine != null
        ? (currentMachine['name'] ?? "Smart Container")
        : "Smart Container EcoCash";

    final int fillPct =
        currentMachine != null ? (currentMachine['fillPercentage'] ?? 0) : 0;
    final bool isFull = fillPct >= 80;
    final String areaInfo = currentMachine != null
        ? (currentMachine['placeName'] ?? currentMachine['address'] ?? '')
        : '';

    return Column(
      children: [
        _destinationCard(
          "container",
          Icons.inventory_2_rounded,
          machineTitle,
          isFull
              ? "Kapasitas hampir penuh ($fillPct%) • $areaInfo"
              : "Terisi $fillPct% • $areaInfo",
          onActionTap: activeMachines.length > 1 ? _openMachineSelector : null,
          actionLabel: activeMachines.length > 1
              ? "Ganti Titik (${activeMachines.length} Mesin)"
              : null,
        ),
        const SizedBox(height: 10),
        _destinationCard(
          "enterprise",
          Icons.factory_rounded,
          "Mitra Daur Ulang (TPS / Pabrik)",
          "Menampung kapasitas besar tanpa batas kuota Smart Container",
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? textDark : borderSubtle,
            width: active ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active ? brandYellow : surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: textDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  active
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: active ? textDark : Colors.grey.shade400,
                ),
              ],
            ),
            if (active && onActionTap != null && actionLabel != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: borderSubtle),
              ),
              InkWell(
                onTap: onActionTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      actionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: primaryNavy),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Catatan untuk Kurir (Opsional)",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: textDark),
            decoration: InputDecoration(
              hintText: "Contoh: Karung sudah diikat rapi di depan teras",
              hintStyle: const TextStyle(fontSize: 12, color: textMuted),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: textMuted),
              filled: true,
              fillColor: surfaceBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomButton() {
    final selectedFleet = _fleetSpecs[_selectedFleetIndex];
    final bool isOverweight = _estimatedWeight > selectedFleet.maxCapacityKg;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Estimasi Diterima",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currencyFormat.format(_estimatedEarnings),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: ecoGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (loading || isOverweight) ? null : _orderPickup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isOverweight ? Colors.grey.shade300 : brandYellow,
                      foregroundColor: textDark,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: textDark, strokeWidth: 2.5),
                          )
                        : Text(
                            isOverweight
                                ? "Muatan Berlebih"
                                : "Pesan ${selectedFleet.title}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
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
    );
  }
}