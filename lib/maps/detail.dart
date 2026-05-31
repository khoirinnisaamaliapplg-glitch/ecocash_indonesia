import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:intl/intl.dart';

class DetailMaps extends StatefulWidget {
  final String sessionId;
  final String name;
  final String address;
  final VoidCallback onBack;

  const DetailMaps({
    super.key,
    required this.sessionId,
    required this.name,
    required this.address,
    required this.onBack,
  });

  @override
  State<DetailMaps> createState() => _DetailMapsState();
}

class _DetailMapsState extends State<DetailMaps> {
  Map<String, dynamic>? _session;
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    if (widget.sessionId == "IDLE") {
      setState(() => _isLoading = false);
    } else {
      _fetchSessionDetail();
    }
  }

  Future<void> _fetchSessionDetail() async {
    if (widget.sessionId.isEmpty || widget.sessionId == "null") {
      setState(() {
        _errorMessage = "ID Sesi tidak valid";
        _isLoading = false;
      });
      return;
    }

    final url = ApiConfig.getSessionDetail(widget.sessionId);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          _session = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Gagal memuat: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Koneksi ke server gagal";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty) return Center(child: Text(_errorMessage));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2E35),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Info Rows
          _infoRow(Icons.location_on, widget.address),
          _infoRowWithStatus(
            Icons.access_time_filled,
            "Operasional Mesin",
            widget.sessionId == "IDLE" ? "Inactive" : "Active",
          ),
          _infoRow(Icons.business, "Managed by PT Ideas Edvolution Technology"),

          const SizedBox(height: 25),

          // Section Green Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF4DB67D),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Icon(Icons.recycling, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Reverse Vending Machines",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(25),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Menggunakan data dari API jika tersedia, contoh logika sederhana:
                      Expanded(
                        child: _buildMachineCard(
                          "Status Sesi",
                          _session?['status'] ?? "-",
                          Colors.green,
                          1.0,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildMachineCard(
                          "Berat",
                          "${_session?['summary']?['currentWeight'] ?? 0} kg",
                          Colors.orange,
                          0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMachineCard(
    String type,
    String status,
    Color statusColor,
    double capacity,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_drink, color: Colors.cyan[300], size: 20),
              const SizedBox(width: 5),
              Text(
                type,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: capacity,
            backgroundColor: Colors.grey[200],
            color: statusColor,
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: Colors.cyan[300], size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _infoRowWithStatus(IconData icon, String text, String status) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyan[300], size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Row(
                  children: [
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.circle, color: Colors.green, size: 8),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
}
