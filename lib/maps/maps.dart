import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// SESUAIKAN IMPORT INI DENGAN PATH DI PROYEKMU
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/maps/detail.dart';

class Maps extends StatefulWidget {
  const Maps({super.key});

  @override
  State<Maps> createState() => _MapsState();
}

class _MapsState extends State<Maps> {
  // Koordinat default jika GPS gagal/belum siap (Bandung)
  LatLng _currentLocation = const LatLng(-6.9175, 107.6191);
  final MapController _mapController = MapController();

  List<dynamic> _machines = [];
  bool _isLoading = true;

  // State UI Detail Sheet
  bool _isShowingDetail = false;
  String _selectedName = "";
  String _selectedAddress = "";

  @override
  void initState() {
    super.initState();
    _determinePosition(); // Ambil GPS dan hit API saat halaman dibuka
  }

  // Fungsi untuk handle izin GPS & ambil lokasi terkini device
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Cek apakah layanan lokasi (GPS) aktif
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar(
        'Layanan lokasi (GPS) dimatikan. Menggunakan lokasi default.',
      );
      _fetchNearestMachines(_currentLocation);
      return;
    }

    // 2. Cek status izin akses lokasi aplikasi
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Izin lokasi ditolak. Menggunakan lokasi default.');
        _fetchNearestMachines(_currentLocation);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('Izin lokasi ditolak permanen di pengaturan HP.');
      _fetchNearestMachines(_currentLocation);
      return;
    }

    // 3. Ambil posisi asli perangkat jika aman
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = userLatLng;
      });

      // Pindahkan kamera peta otomatis ke lokasi user yang baru
      _mapController.move(userLatLng, 14.0);

      // Tembak API menggunakan lokasi asli user
      _fetchNearestMachines(userLatLng);
    } catch (e) {
      _fetchNearestMachines(_currentLocation);
    }
  }

  // Fungsi fetch API berdasarkan parameter koordinat dinamis dari GPS
  Future<void> _fetchNearestMachines(LatLng location) async {
    setState(() => _isLoading = true);

    // Menggunakan fungsi endpoint dari ApiConfig kamu
    final String url = ApiConfig.getNearestMachines(
      location.latitude,
      location.longitude,
    );

    try {
      // Mengirim request dengan header terautentikasi bawaan ApiConfig
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        // FIX: Decode sebagai Map karena format backend membungkus response di dalam Object {}
        final Map<String, dynamic> responseBody = json.decode(response.body);

        setState(() {
          // FIX: Ambil array list mesin dari properti 'data' sesuai standard API-mu
          _machines = responseBody['data'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data (Status: ${response.statusCode})');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal memuat mesin terdekat: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    // List marker gabungan (Lokasi User + Lokasi Mesin dari API)
    List<Marker> mapMarkers = [];

    // 1. Tambahkan Marker Biru untuk posisi User saat ini
    mapMarkers.add(
      Marker(
        point: _currentLocation,
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
      ),
    );

    // 2. Tambahkan Marker Pin untuk setiap mesin dari API secara dinamis
    mapMarkers.addAll(
      _machines.map((machine) {
        double lat = double.parse(machine['latitude'].toString());
        double lng = double.parse(machine['longitude'].toString());

        return Marker(
          point: LatLng(lat, lng),
          width: 50,
          height: 50,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isShowingDetail = true;
                _selectedName = machine['name'] ?? 'Tanpa Nama';
                _selectedAddress = machine['address'] ?? 'Tanpa Alamat';
              });
            },
            child: Image.asset('assets/icons/pin.png', fit: BoxFit.contain),
          ),
        );
      }).toList(),
    );

    return Scaffold(
      body: Stack(
        children: [
          // ================== LAYER 1: PETA ==================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ecocash.app',
              ),
              MarkerLayer(markers: mapMarkers),
            ],
          ),

          // Tombol melayang untuk memposisikan ulang ke GPS Kamu (Kanan Atas)
          Positioned(
            top: 50,
            right: 15,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(Icons.gps_fixed, color: Colors.blue),
              onPressed: () => _determinePosition(),
            ),
          ),

          // ================== LAYER 2: DRAGGABLE SHEET ==================
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.15,
            maxChildSize: 0.92,
            snap: true,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Garis penarik (Handle Bar)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 5,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Konten Utama di dalam Sheet
                    Expanded(
                      child: _isShowingDetail
                          ? DetailMaps(
                              name: _selectedName,
                              address: _selectedAddress,
                              onBack: () =>
                                  setState(() => _isShowingDetail = false),
                            )
                          : _buildMainList(scrollController),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget Tampilan List Utama di dalam Sheet
  Widget _buildMainList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _isLoading
          ? 3
          : _machines.length + 2, // +2 untuk Header & Search Bar
      itemBuilder: (context, index) {
        // Index 0: Banner Header Hijau
        if (index == 0) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF4DB67D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Ecomap Location",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],
          );
        }

        // Index 1: Search Bar & Tabs Kategori
        if (index == 1) {
          return Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: "Search location...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildCategoryTabs(),
              const Divider(height: 40),
            ],
          );
        }

        // Tampilkan loading spinner jika status masih fetching data API
        if (_isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Tampilkan pesan kosong jika tidak ada mesin di sekitar koordinat tersebut
        if (_machines.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("Tidak ada mesin terdekat di sekitar Anda."),
            ),
          );
        }

        // Index 2 ke atas: Render Item Mesin dari API secara berulang
        final machine = _machines[index - 2];
        String distance = machine['distance'] != null
            ? "${machine['distance']} km"
            : "- km";

        return _locationTile(
          machine['name'] ?? 'Tanpa Nama',
          distance,
          machine['address'] ?? 'Tanpa Alamat',
        );
      },
    );
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip("Recommendation", Icons.thumb_up, true),
          _chip("Favorite", Icons.star_border, false),
          _chip("Nearby", Icons.explore_outlined, false),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, bool active) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE1F5FE) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? Colors.transparent : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: active ? Colors.blue : Colors.grey),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.blue : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationTile(String name, String dist, String sub) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE1F5FE),
        child: Icon(Icons.recycling, color: Colors.blue, size: 20),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(dist, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      subtitle: Text(sub, overflow: TextOverflow.ellipsis),
      onTap: () {
        setState(() {
          _isShowingDetail = true;
          _selectedName = name;
          _selectedAddress = sub;
        });
      },
    );
  }
}
