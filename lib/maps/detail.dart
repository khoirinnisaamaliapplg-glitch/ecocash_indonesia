import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailMaps extends StatefulWidget {
  final Map<String, dynamic> machine;
  final VoidCallback onBack;

  const DetailMaps({super.key, required this.machine, required this.onBack});

  @override
  State<DetailMaps> createState() => _DetailMapsState();
}

class _DetailMapsState extends State<DetailMaps> {
  // ============================================================
  // DATA UTAMA MESIN
  // ============================================================

  String get _name {
    return widget.machine['name']?.toString() ?? 'Tanpa Nama';
  }

  String get _machineCode {
    return widget.machine['machineCode']?.toString() ?? '-';
  }

  String get _machineType {
    return widget.machine['machineType']?.toString() ?? '-';
  }

  String get _status {
    return widget.machine['status']?.toString().trim().toUpperCase() ??
        'UNKNOWN';
  }

  String get _fillLevel {
    return widget.machine['fillLevel']?.toString().trim().toUpperCase() ??
        'EMPTY';
  }

  String get _placeName {
    final value = widget.machine['placeName']?.toString();

    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value;
  }

  String get _district {
    final value = widget.machine['district']?.toString();

    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value;
  }

  String get _subdistrict {
    final value = widget.machine['subdistrict']?.toString();

    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value;
  }

  String get _locationType {
    final value = widget.machine['locationType']?.toString();

    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value;
  }

  String get _address {
    final address = widget.machine['address']?.toString();

    if (address != null && address.trim().isNotEmpty) {
      return address;
    }

    final placeName = widget.machine['placeName']?.toString();

    if (placeName != null && placeName.trim().isNotEmpty) {
      return placeName;
    }

    return 'Alamat tidak tersedia';
  }

  // ============================================================
  // KOORDINAT
  // ============================================================

  double? get _latitude {
    return double.tryParse(widget.machine['latitude']?.toString() ?? '');
  }

  double? get _longitude {
    return double.tryParse(widget.machine['longitude']?.toString() ?? '');
  }

  bool get _coordinatesAvailable {
    return _latitude != null && _longitude != null;
  }

  // ============================================================
  // NILAI NUMERIK
  // ============================================================

  double get _distanceInKm {
    return _toDouble(widget.machine['distanceInKm']);
  }

  double get _currentWeight {
    return _toDouble(widget.machine['currentWeight']);
  }

  double get _maxWeight {
    return _toDouble(widget.machine['maxWeight']);
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ============================================================
  // STATUS MESIN
  // ============================================================

  bool get _isOperating {
    return _status == 'OPERATING';
  }

  Color get _statusColor {
    switch (_status) {
      case 'OPERATING':
        return const Color(0xFF2E7D32);

      case 'MAINTENANCE':
        return const Color(0xFFF57C00);

      case 'BROKEN':
        return const Color(0xFFC62828);

      default:
        return const Color(0xFF757575);
    }
  }

  double get _machineStatusProgress {
    return _isOperating ? 1.0 : 0.0;
  }

  // ============================================================
  // FILL LEVEL
  // ============================================================

  double get _capacityProgress {
    switch (_fillLevel) {
      case 'EMPTY':
        return 0.0;

      case 'LOW':
        return 0.25;

      case 'MEDIUM':
        return 0.50;

      case 'HIGH':
        return 0.75;

      case 'FULL':
        return 1.0;

      default:
        if (_maxWeight <= 0) {
          return 0.0;
        }

        return (_currentWeight / _maxWeight).clamp(0.0, 1.0);
    }
  }

  Color get _capacityColor {
    switch (_fillLevel) {
      case 'FULL':
        return const Color(0xFFC62828);

      case 'HIGH':
        return const Color(0xFFEF6C00);

      case 'MEDIUM':
        return const Color(0xFFF9A825);

      case 'LOW':
        return const Color(0xFF43A047);

      case 'EMPTY':
        return const Color(0xFF2E7D32);

      default:
        return const Color(0xFF757575);
    }
  }

  IconData get _capacityIcon {
    switch (_fillLevel) {
      case 'FULL':
        return Icons.delete_rounded;

      case 'HIGH':
      case 'MEDIUM':
        return Icons.delete_outline_rounded;

      case 'LOW':
      case 'EMPTY':
      default:
        return Icons.delete_outline_rounded;
    }
  }

  // ============================================================
  // GOOGLE MAPS
  // ============================================================

  Future<void> _openGoogleMaps() async {
    final latitude = _latitude;
    final longitude = _longitude;

    if (latitude == null || longitude == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat mesin tidak tersedia')),
      );

      return;
    }

    final Uri googleMapsUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
    });

    try {
      final bool success = await launchUrl(
        googleMapsUri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Maps tidak dapat dibuka')),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka Google Maps')),
      );
    }
  }

  // ============================================================
  // HALAMAN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 18),

          _buildLocationCard(),

          const SizedBox(height: 14),

          _buildNavigateButton(),

          const SizedBox(height: 24),

          const Text(
            'Informasi Mesin',
            style: TextStyle(
              color: Color(0xFF1A2E35),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          _buildMachineInformation(),

          const SizedBox(height: 24),

          _buildCapacitySection(),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.recycling_rounded,
            color: Color(0xFF4DB67D),
            size: 31,
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A2E35),
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 7),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: _statusColor),
                    const SizedBox(width: 6),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: widget.onBack,
          tooltip: 'Tutup detail',
          icon: const Icon(Icons.close_rounded, color: Color(0xFF757575)),
        ),
      ],
    );
  }

  // ============================================================
  // INFORMASI LOKASI
  // ============================================================

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.location_on_outlined,
            label: 'Alamat',
            value: _address,
          ),

          const SizedBox(height: 14),

          _infoRow(
            icon: Icons.route_outlined,
            label: 'Jarak dari lokasi Anda',
            value: '${_distanceInKm.toStringAsFixed(2)} km',
          ),
        ],
      ),
    );
  }

  Widget _buildNavigateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _coordinatesAvailable ? _openGoogleMaps : null,
        icon: const Icon(Icons.navigation_rounded, size: 21),
        label: const Text(
          'Navigasi dengan Google Maps',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4285F4),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFORMASI DETAIL MESIN
  // ============================================================

  Widget _buildMachineInformation() {
    final String coordinates = _coordinatesAvailable
        ? '${_latitude!.toStringAsFixed(6)}, '
              '${_longitude!.toStringAsFixed(6)}'
        : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8ECEF)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _detailRow(label: 'Kode mesin', value: _machineCode),

          const Divider(height: 24),

          _detailRow(label: 'Tipe mesin', value: _machineType),

          const Divider(height: 24),

          _detailRow(label: 'Status mesin', value: _status),

          const Divider(height: 24),

          _detailRow(label: 'Tingkat keterisian', value: _fillLevel),

          const Divider(height: 24),

          _detailRow(label: 'Tipe lokasi', value: _locationType),

          const Divider(height: 24),

          _detailRow(label: 'Nama tempat', value: _placeName),

          const Divider(height: 24),

          _detailRow(label: 'Kecamatan', value: _district),

          const Divider(height: 24),

          _detailRow(label: 'Kelurahan', value: _subdistrict),

          const Divider(height: 24),

          _detailRow(label: 'Koordinat', value: coordinates),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS DAN KAPASITAS
  // ============================================================

  Widget _buildCapacitySection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF4DB67D),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.recycling_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reverse Vending Machine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMachineCard(
                        icon: Icons.power_settings_new_rounded,
                        title: 'Status Mesin',
                        value: _status,
                        color: _statusColor,
                        progress: _machineStatusProgress,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _buildMachineCard(
                        icon: _capacityIcon,
                        title: 'Kapasitas Mesin',
                        value: _fillLevel,
                        color: _capacityColor,
                        progress: _capacityProgress,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _weightInformation(
                          label: 'Berat Saat Ini',
                          value: '${_currentWeight.toStringAsFixed(2)} kg',
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 38,
                        color: const Color(0xFFECEFF1),
                      ),

                      Expanded(
                        child: _weightInformation(
                          label: 'Kapasitas Maksimum',
                          value: '${_maxWeight.toStringAsFixed(2)} kg',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF26A69A), size: 19),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF455A64),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFFECEFF1),
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _weightInformation({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
        ),

        const SizedBox(height: 5),

        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WIDGET PEMBANTU
  // ============================================================

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF26A69A), size: 22),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF455A64),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF757575), fontSize: 12),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF263238),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
