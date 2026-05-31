import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:ecocash_indonesia/maps/detail.dart';

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

  // State untuk Detail
  String _selectedId = "";
  String _selectedName = "";
  String _selectedAddress = "";

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fetchNearestMachines(_currentLocation);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng userLatLng = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = userLatLng);
      _mapController.move(userLatLng, 14.0);
      _fetchNearestMachines(userLatLng);
    } catch (e) {
      _fetchNearestMachines(_currentLocation);
    }
  }

  Future<void> _fetchNearestMachines(LatLng location) async {
    setState(() => _isLoading = true);
    final String url = ApiConfig.getNearestMachines(
      location.latitude,
      location.longitude,
    );
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        setState(() {
          _machines = responseBody['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openDetail(Map<String, dynamic> machine) {
    setState(() {
      _isShowingDetail = true;
      _selectedId = machine['activeSessionId']?.toString() ?? "IDLE";
      _selectedName = machine['name']?.toString() ?? 'Tanpa Nama';
      _selectedAddress = machine['address']?.toString() ?? 'Tanpa Alamat';
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> mapMarkers = [
      Marker(
        point: _currentLocation,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
      ),
      ..._machines.map((machine) {
        double lat =
            double.tryParse(machine['latitude']?.toString() ?? '0') ?? 0.0;
        double lng =
            double.tryParse(machine['longitude']?.toString() ?? '0') ?? 0.0;
        return Marker(
          point: LatLng(lat, lng),
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _openDetail(machine),
            child: Image.asset('assets/icons/pin.png', fit: BoxFit.contain),
          ),
        );
      }),
    ];

    return Scaffold(
      body: Stack(
        children: [
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
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.15,
            maxChildSize: 0.92,
            snap: true,
            builder: (context, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
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
                        ? DetailMaps(
                            sessionId: _selectedId,
                            name: _selectedName,
                            address: _selectedAddress,
                            onBack: () =>
                                setState(() => _isShowingDetail = false),
                          )
                        : _buildMainList(controller),
                  ),
                ],
              ),
            ),
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip("Recommendation", Icons.thumb_up, true),
                    _chip("Favorite", Icons.star_border, false),
                    _chip("Nearby", Icons.explore_outlined, false),
                  ],
                ),
              ),
              const Divider(height: 40),
            ],
          );
        }
        if (_isLoading) return const Center(child: CircularProgressIndicator());

        final machine = _machines[index - 2];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE1F5FE),
            child: Icon(Icons.recycling, color: Colors.blue),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  machine['name'] ?? 'Tanpa Nama',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "${machine['distance'] ?? 0} km",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          subtitle: Text(machine['address'] ?? 'Tanpa Alamat'),
          onTap: () => _openDetail(machine),
        );
      },
    );
  }

  Widget _chip(String label, IconData icon, bool active) => Container(
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
