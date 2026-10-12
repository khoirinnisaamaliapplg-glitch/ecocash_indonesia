import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../ipconfig.dart';
import '../profile/daftar_alamat_page.dart';
import 'riwayat_pickup_page.dart';

class PickupWastePage extends StatefulWidget {
  const PickupWastePage({super.key});

  @override
  State<PickupWastePage> createState() => _PickupWastePageState();
}

class _PickupWastePageState extends State<PickupWastePage> {
  final Color primary = const Color(0xff0BCFD1);

  // Alamat aktif dari Database
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddress = true;

  // Bobot Sampah yang Diinput
  double _estimatedWeight = 15.0;

  // Spesifikasi Kapasitas Resmi Armada EcoCash
  final List<Map<String, dynamic>> _fleetSpecs = [
    {
      'type': 'MOTORCYCLE',
      'title': 'Motor Roda 3',
      'icon': Icons.two_wheeler,
      'maxCapacityKg': 35.0,
      'distance': '1.2 Km',
      'time': '5 menit',
    },
    {
      'type': 'CART',
      'title': 'Gerobak Motor',
      'icon': Icons.shopping_cart_outlined,
      'maxCapacityKg': 150.0,
      'distance': '1.8 Km',
      'time': '8 menit',
    },
    {
      'type': 'CAR',
      'title': 'Mobil Pickup',
      'icon': Icons.local_shipping,
      'maxCapacityKg': 600.0,
      'distance': '2.5 Km',
      'time': '12 menit',
    },
  ];

  int _selectedFleetIndex = 0;
  String selectedDestination = "container"; // 'container' atau 'enterprise'
  int _selectedMachineIndex = 0; // Menyimpan indeks mesin database yang dipilih warga

  bool loading = false;
  bool isFetchingMachines = true;
  List<dynamic> activeMachines = [];

  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAddressesFromDb();
    _loadInitialMachines();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // 1. Ambil alamat dari Database melalui REST API
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
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat alamat dari DB: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  // 2. Ambil seluruh data Smart Container aktif dari Database Backend
  Future<void> _loadInitialMachines() async {
    setState(() => isFetchingMachines = true);
    try {
      final machineUri = Uri.parse(ApiConfig.getPublicMachines);
      final machineRes = await http.get(machineUri, headers: ApiConfig.headers);
      if (machineRes.statusCode == 200) {
        final machineData = jsonDecode(machineRes.body);
        if (machineData['data'] is List && (machineData['data'] as List).isNotEmpty) {
          setState(() {
            activeMachines = machineData['data'];
            // Pastikan index seleksi selalu valid
            if (_selectedMachineIndex >= activeMachines.length) {
              _selectedMachineIndex = 0;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat data mesin dari DB: $e");
    } finally {
      if (mounted) setState(() => isFetchingMachines = false);
    }
  }

  // Evaluasi batas muatan armada saat slider digeser
  void _onWeightChanged(double newWeight) {
    setState(() {
      _estimatedWeight = newWeight.clamp(1.0, 600.0);
      _autoAdjustFleet();
    });
  }

  void _autoAdjustFleet() {
    final currentFleet = _fleetSpecs[_selectedFleetIndex];
    final double maxCap = currentFleet['maxCapacityKg'];

    if (_estimatedWeight > maxCap) {
      final suitableIndex = _fleetSpecs.indexWhere(
        (f) => _estimatedWeight <= (f['maxCapacityKg'] as double),
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
    }
  }

  // Dialog Bottom Sheet untuk memilih seluruh Smart Container dari Database
  void _openMachineSelector() {
    if (activeMachines.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                      const Text(
                        "Pilih Smart Container Tujuan",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${activeMachines.length} Mesin Aktif",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                        ),
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
                      final bool isSelected = _selectedMachineIndex == i;
                      final int fill = m['fillPercentage'] ?? 0;
                      final String area = m['placeName'] ?? m['address'] ?? 'Kota Bandung';
                      final String code = m['machineCode'] ?? 'MCH-$i';

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? primary.withOpacity(0.15) : const Color(0xFFF4F6F8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: isSelected ? primary : Colors.grey,
                            size: 24,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              m['name'] ?? 'Smart Container',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                code,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "$area • Terisi $fill%",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? primary : Colors.grey.shade400,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedMachineIndex = i;
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
  }

  // 3. Kirim pesanan penjemputan ke Backend
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

    final selectedFleet = _fleetSpecs[_selectedFleetIndex];
    final double maxCap = selectedFleet['maxCapacityKg'];

    if (_estimatedWeight > maxCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Muatan ${_estimatedWeight.toStringAsFixed(0)} kg melebihi kapasitas ${selectedFleet['title']}. Harap pilih armada yang lebih besar."),
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
        if (activeMachines.isNotEmpty && _selectedMachineIndex < activeMachines.length) {
          final targetMachine = activeMachines[_selectedMachineIndex];
          final String mName = targetMachine['name'] ?? targetMachine['placeName'] ?? "Smart Container";
          destinationTitle = "Smart Container ($mName)";
          targetMachineId = targetMachine['id'];
        } else {
          destinationTitle = "Smart Container (Umum)";
        }
      } else {
        destinationTitle = "EcoCash Enterprise Partner (Recycler)";
      }

      final String finalAddress = (_selectedAddress!['detail'] ?? _selectedAddress!['address'] ?? 'Alamat Warga').toString();

      final payload = {
        "title": "Penjemputan Sampah - Warga",
        "address": finalAddress,
        "notes": "${_notesController.text.trim()} (Armada: ${selectedFleet['title']} | Tujuan: $destinationTitle)",
        "estimatedWeight": _estimatedWeight,
        "vehicleType": selectedFleet['type'],
        "materialCategory": "Plastik PET & Karton",
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
              "Permintaan jemput sampah berhasil dibuat menggunakan armada ${selectedFleet['title']}. Tujuan penyetoran: $destinationTitle.",
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
                child: const Text("Pantau Status", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Gagal membuat pesanan'), backgroundColor: Colors.red),
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
          const SizedBox(height: 6),
          Text(
            'Armada yang tidak sanggup membawa muatan ini otomatis terkunci.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
        final double maxCap = fleet['maxCapacityKg'];
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
                      content: Text('Armada ${fleet['title']} tidak muat! Maksimal kapasitas hanya ${maxCap.toInt()} kg.'),
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
                    child: Icon(fleet['icon'] as IconData, color: isCapable ? primary : Colors.grey, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(fleet['title'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                          '📍 Radius ${fleet['distance']} • Tiba ~${fleet['time']}',
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

    final Map<String, dynamic>? currentMachine =
        (activeMachines.isNotEmpty && _selectedMachineIndex < activeMachines.length)
            ? activeMachines[_selectedMachineIndex]
            : null;

    final String machineTitle = currentMachine != null
        ? (currentMachine['name'] ?? "Smart Container")
        : "Smart Container EcoCash";

    final int fillPct = currentMachine != null ? (currentMachine['fillPercentage'] ?? 0) : 0;
    final bool isFull = fillPct >= 80;
    final String areaInfo = currentMachine != null ? (currentMachine['placeName'] ?? '') : '';

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
          "Siap menampung kapasitas besar tanpa batas",
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
    final bool isOverweight = _estimatedWeight > (selectedFleet['maxCapacityKg'] as double);

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
                    isOverweight ? "Muatan Melebihi Kapasitas Armada" : "Pesan ${selectedFleet['title']} (${_estimatedWeight.toStringAsFixed(0)} Kg)",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}