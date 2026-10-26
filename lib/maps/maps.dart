import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/maps/detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class Maps extends StatefulWidget {
  const Maps({super.key});

  @override
  State<Maps> createState() => _MapsState();
}

class _MapsState extends State<Maps> {
  final Color primary = const Color(0xFF4DB67D);
  LatLng _currentLocation = const LatLng(-6.9175, 107.6191); // Default Kota Bandung

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _machines = [];
  bool _isLoading = true;
  bool _isShowingDetail = false;
  Map<String, dynamic>? _selectedMachine;

  // Filter Chip Aktif: 'ALL', 'AVAILABLE', 'NEARBY'
  String _activeFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _fetchNearestMachines(_currentLocation);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await _fetchNearestMachines(_currentLocation);
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng userLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _currentLocation = userLatLng;
      });

      _mapController.move(userLatLng, 13);
      await _fetchNearestMachines(userLatLng);
    } catch (_) {
      await _fetchNearestMachines(_currentLocation);
    }
  }

  Future<void> _fetchNearestMachines(LatLng location) async {
    setState(() => _isLoading = true);

    try {
      final String nearestUrl = ApiConfig.getNearestMachines(
        location.latitude,
        location.longitude,
      );

      final response = await http.get(
        Uri.parse(nearestUrl),
        headers: ApiConfig.headers,
      );

      List<dynamic> fetched = [];
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        fetched = decoded['data'] is List ? decoded['data'] : [];
      }

      // Fallback Cerdas: Jika GPS pengguna berada di luar radius ST_DWithin backend,
      // ambil seluruh mesin aktif publik dan hitung jarak Haversine dari titik user
      if (fetched.isEmpty) {
        final publicRes = await http.get(
          Uri.parse(ApiConfig.getPublicMachines),
          headers: ApiConfig.headers,
        );

        if (publicRes.statusCode == 200) {
          final publicDecoded = jsonDecode(publicRes.body);
          final rawList = publicDecoded['data'] is List ? publicDecoded['data'] : [];

          fetched = rawList.map((m) {
            final lat = double.tryParse(m['latitude']?.toString() ?? '');
            final lng = double.tryParse(m['longitude']?.toString() ?? '');
            double distKm = 0.0;
            if (lat != null && lng != null) {
              distKm = Geolocator.distanceBetween(
                location.latitude,
                location.longitude,
                lat,
                lng,
              ) / 1000.0;
            }
            final mapData = Map<String, dynamic>.from(m);
            mapData['distanceInKm'] = distKm;
            return mapData;
          }).toList();

          fetched.sort((a, b) => ((a['distanceInKm'] ?? 0) as double)
              .compareTo((b['distanceInKm'] ?? 0) as double));
        }
      }

      if (!mounted) return;
      setState(() {
        _machines = fetched;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _machines = [];
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredMachines {
    return _machines.where((item) {
      final m = Map<String, dynamic>.from(item);
      final String name = (m['name'] ?? '').toString().toLowerCase();
      final String place = (m['placeName'] ?? '').toString().toLowerCase();
      final String addr = (m['address'] ?? '').toString().toLowerCase();
      final String status = (m['status'] ?? '').toString().toUpperCase();
      final String fill = (m['fillLevel'] ?? '').toString().toUpperCase();

      // Filter Pencarian Teks
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !place.contains(q) && !addr.contains(q)) {
          return false;
        }
      }

      // Filter Kategori Chip
      if (_activeFilter == 'AVAILABLE') {
        if (status != 'OPERATING' || fill == 'FULL') return false;
      }

      return true;
    }).toList();
  }

  void _openDetail(Map<String, dynamic> machine) {
    final double? latitude = double.tryParse(machine['latitude']?.toString() ?? '');
    final double? longitude = double.tryParse(machine['longitude']?.toString() ?? '');

    setState(() {
      _selectedMachine = Map<String, dynamic>.from(machine);
      _isShowingDetail = true;
    });

    if (latitude != null && longitude != null) {
      _mapController.move(LatLng(latitude, longitude), 15.5);
    }
  }

  void _closeDetail() {
    setState(() {
      _isShowingDetail = false;
      _selectedMachine = null;
    });
  }

  Color _getMarkerStatusColor(String status, String fillLevel) {
    if (status != 'OPERATING') return const Color(0xFFF57C00); // Maintenance
    if (fillLevel == 'FULL') return const Color(0xFFC62828); // Penuh
    return const Color(0xFF2E7D32); // Siap pakai
  }

  String _formatDistance(dynamic val) {
    if (val == null) return '-';
    final double? d = double.tryParse(val.toString());
    if (d == null) return '-';
    if (d < 1.0) {
      return '${(d * 1000).toInt()} m';
    }
    return '${d.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMachines;

    final List<Marker> mapMarkers = [
      Marker(
        point: _currentLocation,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.my_location, color: Colors.blue, size: 24),
          ),
        ),
      ),
      ...filtered.map((machineData) {
        final Map<String, dynamic> machine = Map<String, dynamic>.from(machineData);
        final double? lat = double.tryParse(machine['latitude']?.toString() ?? '');
        final double? lng = double.tryParse(machine['longitude']?.toString() ?? '');

        if (lat == null || lng == null) return null;

        final String status = (machine['status'] ?? 'OPERATING').toString().toUpperCase();
        final String fill = (machine['fillLevel'] ?? 'LOW').toString().toUpperCase();
        final Color pinColor = _getMarkerStatusColor(status, fill);
        final bool isSelected = _selectedMachine?['id'] == machine['id'];

        return Marker(
          point: LatLng(lat, lng),
          alignment: Alignment.bottomCenter,
          width: isSelected ? 52 : 44,
          height: isSelected ? 52 : 44,
          child: GestureDetector(
            onTap: () => _openDetail(machine),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: pinColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: pinColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        );
      }).whereType<Marker>(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ecocash.app',
              ),
              MarkerLayer(markers: mapMarkers),
            ],
          ),

          // Tombol Kembali
          Positioned(
            top: 50,
            left: 15,
            child: FloatingActionButton(
              heroTag: "btn_back",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.black87),
            ),
          ),

          // Tombol Reset Lokasi GPS
          Positioned(
            top: 50,
            right: 15,
            child: FloatingActionButton(
              heroTag: "btn_gps",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _determinePosition,
              child: const Icon(Icons.gps_fixed, color: Color(0xFF4285F4)),
            ),
          ),

          // Bottom Sheet Daftar Mesin & Status
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.16,
            maxChildSize: 0.92,
            snap: true,
            builder: (BuildContext context, ScrollController controller) {
              return Material(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                elevation: 12,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      height: 5,
                      width: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Expanded(
                      child: _isShowingDetail
                          ? (_selectedMachine == null
                              ? const SizedBox.shrink()
                              : DetailMaps(
                                  machine: _selectedMachine!,
                                  onBack: _closeDetail,
                                ))
                          : _buildMainList(controller, filtered),
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

  Widget _buildMainList(ScrollController controller, List<dynamic> filtered) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _isLoading ? 3 : filtered.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Smart Container Terdekat',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '${filtered.length} kontainer ditemukan aktif di sekitar Anda',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          );
        }

        if (index == 1) {
          return Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari kontainer, stasiun, jalan...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Semua', 'ALL', Icons.apps),
                    _chip('Siap Pakai', 'AVAILABLE', Icons.check_circle_outline),
                  ],
                ),
              ),
              const Divider(height: 28),
            ],
          );
        }

        if (_isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Tidak ada Smart Container yang cocok dengan pencarian.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        final Map<String, dynamic> machine = Map<String, dynamic>.from(filtered[index - 2]);
        final String name = machine['name']?.toString() ?? 'Smart Container';
        final String address = machine['address']?.toString() ?? machine['placeName'] ?? 'Lokasi Mesin';
        final String status = (machine['status'] ?? 'OPERATING').toString().toUpperCase();
        final String fill = (machine['fillLevel'] ?? 'LOW').toString().toUpperCase();
        final String distStr = _formatDistance(machine['distanceInKm']);

        final Color statusColor = _getMarkerStatusColor(status, fill);
        final bool isFull = fill == 'FULL';
        final bool isOperating = status == 'OPERATING';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.12),
              child: Icon(Icons.recycling_rounded, color: statusColor, size: 22),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  distStr,
                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFull ? 'Kapasitas Penuh' : (isOperating ? 'Beroperasi' : 'Perawatan'),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: $fill',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            onTap: () => _openDetail(machine),
          ),
        );
      },
    );
  }

  Widget _chip(String label, String filterKey, IconData icon) {
    final bool active = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filterKey),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? primary : Colors.grey.shade300,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: active ? primary : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? primary : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}