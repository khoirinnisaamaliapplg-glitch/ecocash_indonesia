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
  LatLng _currentLocation = const LatLng(-6.9175, 107.6191);

  final MapController _mapController = MapController();

  List<dynamic> _machines = [];

  bool _isLoading = true;
  bool _isShowingDetail = false;

  // Menyimpan seluruh data mesin yang dipilih.
  Map<String, dynamic>? _selectedMachine;

  @override
  void initState() {
    super.initState();
    _determinePosition();
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

      _mapController.move(userLatLng, 14);

      await _fetchNearestMachines(userLatLng);
    } catch (_) {
      await _fetchNearestMachines(_currentLocation);
    }
  }

  Future<void> _fetchNearestMachines(LatLng location) async {
    setState(() {
      _isLoading = true;
    });

    final String url = ApiConfig.getNearestMachines(
      location.latitude,
      location.longitude,
    );

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        setState(() {
          _machines = responseBody['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _machines = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _machines = [];
        _isLoading = false;
      });
    }
  }

  void _openDetail(Map<String, dynamic> machine) {
    final double? latitude = double.tryParse(
      machine['latitude']?.toString() ?? '',
    );

    final double? longitude = double.tryParse(
      machine['longitude']?.toString() ?? '',
    );

    setState(() {
      _selectedMachine = Map<String, dynamic>.from(machine);

      _isShowingDetail = true;
    });

    // Arahkan peta ke mesin yang dipilih.
    if (latitude != null && longitude != null) {
      _mapController.move(LatLng(latitude, longitude), 16);
    }
  }

  void _closeDetail() {
    setState(() {
      _isShowingDetail = false;
      _selectedMachine = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Marker> mapMarkers = [
      Marker(
        point: _currentLocation,
        alignment: Alignment.center,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
      ),

      ..._machines.map((machineData) {
        final Map<String, dynamic> machine = Map<String, dynamic>.from(
          machineData,
        );

        final double? latitude = double.tryParse(
          machine['latitude']?.toString() ?? '',
        );

        final double? longitude = double.tryParse(
          machine['longitude']?.toString() ?? '',
        );

        if (latitude == null || longitude == null) {
          return null;
        }

        return Marker(
          point: LatLng(latitude, longitude),
          alignment: Alignment.bottomCenter,
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () => _openDetail(machine),
            child: Image.asset('assets/icons/pin.png', fit: BoxFit.contain),
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
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ecocash.app',
              ),
              MarkerLayer(markers: mapMarkers),
            ],
          ),

          Positioned(
            top: 50,
            right: 15,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _determinePosition,
              child: const Icon(Icons.gps_fixed, color: Colors.blue),
            ),
          ),

          Positioned(
            top: 50,
            left: 15,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.15,
            maxChildSize: 0.92,
            snap: true,
            builder: (BuildContext context, ScrollController controller) {
              return Material(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 5,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    Expanded(
                      child: _isShowingDetail
                          ? _selectedMachine == null
                                ? const SizedBox.shrink()
                                : DetailMaps(
                                    machine: _selectedMachine!,
                                    onBack: _closeDetail,
                                  )
                          : _buildMainList(controller),
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

  Widget _buildMainList(ScrollController controller) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _isLoading ? 3 : _machines.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF4DB67D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Ecomap Location',
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

        if (index == 1) {
          return Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search location...',
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

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Recommendation', Icons.thumb_up, true),
                    _chip('Favorite', Icons.star_border, false),
                    _chip('Nearby', Icons.explore_outlined, false),
                  ],
                ),
              ),

              const Divider(height: 40),
            ],
          );
        }

        if (_isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final Map<String, dynamic> machine = Map<String, dynamic>.from(
          _machines[index - 2],
        );

        final String name = machine['name']?.toString() ?? 'Tanpa Nama';

        final String address = machine['address']?.toString() ?? 'Tanpa Alamat';

        final String status = machine['status']?.toString() ?? 'UNKNOWN';

        final String distance = machine['distanceInKm']?.toString() ?? '0';

        return Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE1F5FE),
              child: Icon(
                Icons.recycling,
                color: status == 'OPERATING' ? Colors.green : Colors.grey,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$distance km',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            subtitle: Text(
              address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _openDetail(machine),
          ),
        );
      },
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
}
