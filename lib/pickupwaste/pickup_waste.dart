import 'package:flutter/material.dart';

class PickupWastePage extends StatefulWidget {
  const PickupWastePage({super.key});

  @override
  State<PickupWastePage> createState() => _PickupWastePageState();
}

class _PickupWastePageState extends State<PickupWastePage> {
  final Color primary = const Color(0xff0BCFD1);

  String selectedDestination = "container";

  bool loading = false;

  final Map<String, String> driver = {
    "name": "Ahmad Fauzi",

    "vehicle": "Motor Roda 3",

    "distance": "1.2 Km",

    "time": "5 menit",
  };

  Future<void> _orderPickup() async {
    setState(() {
      loading = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Permintaan jemput sampah berhasil dibuat"),

        backgroundColor: Colors.green,
      ),
    );
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
                  const SizedBox(height: 20),

                  _locationCard(),

                  const SizedBox(height: 25),

                  _sectionTitle("Kendaraan EcoCash Terdekat"),

                  _driverCard(),

                  const SizedBox(height: 25),

                  _sectionTitle("Pilih Tujuan Pengiriman"),

                  _destinationCard(
                    "container",

                    Icons.inventory_2_outlined,

                    "Smart Container Bandung",

                    "Kapasitas tersedia 60%",
                  ),

                  _destinationCard(
                    "enterprise",

                    Icons.business_outlined,

                    "EcoCash Enterprise Partner",

                    "Mitra daur ulang terdekat 2.5 Km",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: _bottomButton(),
    );
  }

  // =========================
  // HEADER
  // =========================

  Widget _buildHeader() {
    return Container(
      height: 160,

      width: double.infinity,

      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage("assets/bg.png"),

          fit: BoxFit.cover,
        ),

        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),

          bottomRight: Radius.circular(30),
        ),
      ),

      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),

          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.2),

                  shape: BoxShape.circle,
                ),

                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },

                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),

              const SizedBox(width: 15),

              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "Jemput Sampah",

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 23,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      "Cari kendaraan EcoCash terdekat",

                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: primary.withOpacity(.12),

              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(Icons.location_on, color: primary),
          ),

          const SizedBox(width: 15),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  "Lokasi Pengambilan",

                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),

                SizedBox(height: 5),

                Text(
                  "Tasikmalaya, Jawa Barat",

                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),

      child: Text(
        text,

        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _driverCard() {
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 20, right: 20),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),

            decoration: BoxDecoration(
              color: primary.withOpacity(.12),

              borderRadius: BorderRadius.circular(15),
            ),

            child: Icon(Icons.local_shipping, color: primary, size: 35),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  driver["name"]!,

                  style: const TextStyle(
                    fontSize: 17,

                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  driver["vehicle"]!,

                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 8),

                Text("📍 ${driver["distance"]}   ⏱ ${driver["time"]}"),
              ],
            ),
          ),

          const Text("🟢", style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _destinationCard(
    String value,

    IconData icon,

    String title,

    String subtitle,
  ) {
    bool active = selectedDestination == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDestination = value;
        });
      },

      child: Container(
        margin: const EdgeInsets.only(top: 12, left: 20, right: 20),

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(
            color: active ? primary : Colors.transparent,

            width: 2,
          ),
        ),

        child: Row(
          children: [
            Icon(icon, color: active ? primary : Colors.grey, size: 32),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,

                      fontSize: 16,
                    ),
                  ),

                  Text(
                    subtitle,

                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),

            Icon(
              active ? Icons.check_circle : Icons.circle_outlined,

              color: active ? primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),

        color: Colors.white,

        child: SizedBox(
          height: 55,

          width: double.infinity,

          child: ElevatedButton(
            onPressed: loading ? null : _orderPickup,

            style: ElevatedButton.styleFrom(
              backgroundColor: primary,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),

            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "🚚 Pesan Jemput Sampah",

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 17,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
