import 'package:flutter/material.dart';

class DetailMaps extends StatelessWidget {
  final String name;
  final String address;
  final VoidCallback onBack;

  const DetailMaps({
    super.key,
    required this.name,
    required this.address,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2E35),
                  ),
                ),
              ),
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Info Rows
          _infoRow(Icons.location_on, address),
          _infoRowWithStatus(
            Icons.access_time_filled,
            "Monday to sunday 7am to 10pm",
            "Open now",
          ),
          _infoRow(Icons.business, "Located By PT Ideas Edvolution Technology"),

          const SizedBox(height: 25),

          // Section Green Card (Reverse Vending Machines)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF4DB67D),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: const [
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

                // Area Putih di dalam Hijau untuk Kartu Mesin
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
                      // Kartu Plastic
                      Expanded(
                        child: _buildMachineCard(
                          "Plastic",
                          "Closed",
                          Colors.red,
                          0.97,
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Kartu Glass
                      Expanded(
                        child: _buildMachineCard(
                          "Glass",
                          "Open now",
                          Colors.green,
                          0.47,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // Tombol Action Bawah
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.star_border, color: Colors.grey),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Open Directions",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Widget untuk Kartu Mesin (Plastic/Glass)
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
              Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          const Text(
            "Capacity :",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 5),
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

  Widget _infoRow(IconData icon, String text) {
    return Padding(
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
  }

  Widget _infoRowWithStatus(IconData icon, String text, String status) {
    return Padding(
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
}
