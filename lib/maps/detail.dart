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
  String get _name => widget.machine['name']?.toString() ?? 'Tanpa Nama';
  String get _machineCode => widget.machine['machineCode']?.toString() ?? '-';
  String get _machineType => widget.machine['machineType']?.toString() ?? 'CONTAINER';
  String get _status => widget.machine['status']?.toString().trim().toUpperCase() ?? 'OPERATING';
  String get _fillLevel => widget.machine['fillLevel']?.toString().trim().toUpperCase() ?? 'EMPTY';

  String get _placeName {
    final value = widget.machine['placeName']?.toString();
    return (value == null || value.trim().isEmpty) ? '-' : value;
  }

  String get _district {
    final value = widget.machine['district']?.toString();
    return (value == null || value.trim().isEmpty) ? '-' : value;
  }

  String get _subdistrict {
    final value = widget.machine['subdistrict']?.toString();
    return (value == null || value.trim().isEmpty) ? '-' : value;
  }

  String get _locationType {
    final value = widget.machine['locationType']?.toString();
    return (value == null || value.trim().isEmpty) ? '-' : value;
  }

  String get _address {
    final address = widget.machine['address']?.toString();
    if (address != null && address.trim().isNotEmpty) return address;
    final placeName = widget.machine['placeName']?.toString();
    if (placeName != null && placeName.trim().isNotEmpty) return placeName;
    return 'Alamat tidak tersedia';
  }

  double? get _latitude => double.tryParse(widget.machine['latitude']?.toString() ?? '');
  double? get _longitude => double.tryParse(widget.machine['longitude']?.toString() ?? '');
  bool get _coordinatesAvailable => _latitude != null && _longitude != null;

  double get _distanceInKm => _toDouble(widget.machine['distanceInKm']);
  double get _currentWeight => _toDouble(widget.machine['currentWeight']);
  double get _maxWeight => _toDouble(widget.machine['maxWeight'] ?? 200);

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool get _isOperating => _status == 'OPERATING';
  bool get _isFull => _fillLevel == 'FULL';

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

  double get _capacityProgress {
    switch (_fillLevel) {
      case 'EMPTY':
        return 0.0;
      case 'LOW':
        return 0.25;
      case 'HALF':
      case 'MEDIUM':
        return 0.50;
      case 'HIGH':
        return 0.75;
      case 'FULL':
        return 1.0;
      default:
        if (_maxWeight <= 0) return 0.0;
        return (_currentWeight / _maxWeight).clamp(0.0, 1.0);
    }
  }

  Color get _capacityColor {
    switch (_fillLevel) {
      case 'FULL':
        return const Color(0xFFC62828);
      case 'HIGH':
        return const Color(0xFFEF6C00);
      case 'HALF':
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
      default:
        return Icons.delete_outline_rounded;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (_isFull) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kontainer ini sudah penuh. Petugas kurir sedang dijadwalkan untuk pengosongan muatan.',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
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

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.recycling_rounded,
            color: Color(0xFF4DB67D),
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        fontSize: 11,
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
          const SizedBox(height: 12),
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
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _coordinatesAvailable ? _openGoogleMaps : null,
        icon: const Icon(Icons.navigation_rounded, size: 20),
        label: const Text(
          'Navigasi dengan Google Maps',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4285F4),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineInformation() {
    final String coordinates = _coordinatesAvailable
        ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
        : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8ECEF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _detailRow(label: 'Kode mesin', value: _machineCode),
          const Divider(height: 20),
          _detailRow(label: 'Tipe mesin', value: _machineType),
          const Divider(height: 20),
          _detailRow(label: 'Status mesin', value: _status),
          const Divider(height: 20),
          _detailRow(label: 'Tingkat keterisian', value: _fillLevel),
          const Divider(height: 20),
          _detailRow(label: 'Wilayah / Area', value: '$_district, $_subdistrict'),
          const Divider(height: 20),
          _detailRow(label: 'Koordinat Spasial', value: coordinates),
        ],
      ),
    );
  }

  Widget _buildCapacitySection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF4DB67D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kapasitas Smart Container',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
                        progress: _isOperating ? 1.0 : 0.0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMachineCard(
                        icon: _capacityIcon,
                        title: 'Kapasitas',
                        value: _fillLevel,
                        color: _capacityColor,
                        progress: _capacityProgress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _weightInformation(
                          label: 'Berat Saat Ini',
                          value: '${_currentWeight.toStringAsFixed(1)} kg',
                        ),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFFECEFF1)),
                      Expanded(
                        child: _weightInformation(
                          label: 'Kapasitas Maksimal',
                          value: '${_maxWeight.toStringAsFixed(1)} kg',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF26A69A), size: 18),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFFECEFF1),
            color: color,
            borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: 4),
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

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF26A69A), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF455A64),
                  fontSize: 12,
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
        const SizedBox(width: 10),
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