import 'package:ecocash_indonesia/maps/detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Maps extends StatefulWidget {
  const Maps({super.key});

  @override
  State<Maps> createState() => _MapsState();
}

class _MapsState extends State<Maps> {
  final LatLng _center = const LatLng(-6.9175, 107.6191);

  // State untuk mengontrol tampilan di dalam Sheet
  bool _isShowingDetail = false;
  String _selectedName = "";
  String _selectedAddress = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Layer Peta
          FlutterMap(
            options: MapOptions(initialCenter: _center, initialZoom: 14.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ecocash.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Layer Kartu Draggable
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
                    // Handle Bar (Garis tarik)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 5,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Konten Dinamis
                    Expanded(
                      child: _isShowingDetail
                          ? DetailMaps(
                              // Jika sedang melihat detail
                              name: _selectedName,
                              address: _selectedAddress,
                              onBack: () =>
                                  setState(() => _isShowingDetail = false),
                            )
                          : _buildMainList(
                              scrollController,
                            ), // Jika sedang melihat list
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

  // Tampilan Daftar Lokasi (Default)
  Widget _buildMainList(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Header Hijau
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

        // Search Bar
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

        // Tabs Kategori
        _buildCategoryTabs(),
        const Divider(height: 40),

        // Daftar Lokasi Tile
        _locationTile(
          "Ecomap Buahbatu",
          "10 km",
          "Jl. Buahbatu no 45 Desa cipagalo...",
        ),
        _locationTile(
          "Ecomap Pasir Kaliki",
          "40 km",
          "Jl. Pasir Kaliki no 21 Desa Ciomas...",
        ),
        _locationTile(
          "Ecomap Setiabudi",
          "25 km",
          "Jl. Setiabudi no 12 Desa Sukamaju...",
        ),
        _locationTile(
          "Ecomap Dago",
          "35 km",
          "Jl. Dago no 33 Desa Cibiru Kecam...",
        ),
        _locationTile(
          "Ecomap Cihampelas",
          "15 km",
          "Jl. Cihampelas no 7 Desa Cipaku...",
        ),
        const SizedBox(height: 20),
      ],
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
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
