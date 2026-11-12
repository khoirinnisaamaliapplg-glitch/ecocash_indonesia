import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ecocash_indonesia/ipconfig.dart';

class PusatBantuanPage extends StatefulWidget {
  final int initialTabIndex;

  const PusatBantuanPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<PusatBantuanPage> createState() => _PusatBantuanPageState();
}

class _PusatBantuanPageState extends State<PusatBantuanPage>
    with SingleTickerProviderStateMixin {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  // Kontak Resmi EcoCash Indonesia
  static const String _officialWhatsappRaw = '6281214161614';
  static const String _officialWhatsappDisplay = '+62 812-1416-1614';
  static const String _officialEmail = 'info@ecocash.id';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingFaqs = true;
  bool _isLoadingTickets = true;
  bool _isLoadingMaterials = true;
  bool _isLoadingBot = true;
  bool _isLoadingLegal = true;

  List _faqs = [];
  List _tickets = [];
  List _materials = [];
  List _systemAlerts = [];
  List _dynamicCategories = [];
  Map<String, Map<String, String>> _legalDocs = {};

  String _selectedFaqCategory = 'Semua';
  String _searchKeyword = '';
  String _materialStatusFilter = 'ALL';

  Map _botTree = {};
  final List _chatMessages = [];

  final List _defaultProblemCategories = [
    {
      'key': 'Akun & Keamanan',
      'title': 'Akun & Keamanan',
      'subtitle': 'Verifikasi email, ganti sandi, keamanan QR',
      'icon': Icons.shield_outlined,
      'color': const Color(0xFF2563EB),
      'bg': const Color(0xFFDBEAFE),
    },
    {
      'key': 'Pembayaran & Transaksi',
      'title': 'Pembayaran & Transaksi',
      'subtitle': 'Saldo EcoCash, top-up, riwayat & refund',
      'icon': Icons.account_balance_wallet_outlined,
      'color': ecoGreen,
      'bg': const Color(0xFFDCFCE7),
    },
    {
      'key': 'Penggunaan Fitur & Layanan',
      'title': 'Penggunaan Layanan',
      'subtitle': 'Setor mesin RVM, EcoJemput & EcoMart',
      'icon': Icons.recycling_rounded,
      'color': const Color(0xFFD97706),
      'bg': const Color(0xFFFEF3C7),
    },
    {
      'key': 'Kendala Teknis',
      'title': 'Kendala Teknis',
      'subtitle': 'Mesin error, selisih timbangan, OTP gagal',
      'icon': Icons.build_circle_outlined,
      'color': const Color(0xFFDC2626),
      'bg': const Color(0xFFFEE2E2),
    },
  ];

  final List _fallbackFaqs = [
    {
      'id': -1,
      'category': 'Akun & Keamanan',
      'question': 'Bagaimana cara mengubah kata sandi atau memulihkan akun yang lupa password?',
      'answer':
          'Masuk ke halaman Login lalu ketuk "Lupa Kata Sandi". Masukkan email atau nomor WhatsApp terdaftar untuk menerima kode OTP verifikasi, kemudian buat kata sandi baru minimal 8 karakter.',
    },
    {
      'id': -2,
      'category': 'Pembayaran & Transaksi',
      'question': 'Berapa lama saldo masuk setelah setor botol di Smart Container atau EcoJemput?',
      'answer':
          'Untuk penyetoran di Smart Container (RVM), saldo otomatis masuk ke dompet EcoCash segera setelah Anda menekan tombol Konfirmasi di layar mesin/aplikasi. Untuk EcoJemput, saldo dikreditkan otomatis setelah kurir mitra menyelesaikan penimbangan.',
    },
    {
      'id': -3,
      'category': 'Penggunaan Fitur & Layanan',
      'question': 'Bagaimana cara menyetor sampah botol plastik ke mesin RVM?',
      'answer':
          '1. Buka menu EcoDrop untuk menemukan lokasi Smart Container terdekat.\n2. Ketuk tombol Pindai di kartu saldo beranda dan arahkan kamera ke QR layar mesin.\n3. Masukkan botol plastik PET dalam kondisi kosong dan bersih satu per satu.\n4. Tekan Selesai & Konfirmasi untuk mencairkan saldo.',
    },
    {
      'id': -4,
      'category': 'Kendala Teknis',
      'question': 'Apa yang harus dilakukan jika mesin penuh, rusak, atau berat timbangan tidak sesuai?',
      'answer':
          'Segera laporkan melalui tab "Tiket & Status" -> "Buat Tiket". Pilih kategori Mesin Rusak atau Selisih Timbangan, sertakan nomor/lokasi mesin serta foto bukti agar tim teknisi segera menindaklanjuti.',
    },
    {
      'id': -5,
      'category': 'Pembayaran & Transaksi',
      'question': 'Bagaimana cara membatalkan pesanan atau mengajukan pengembalian dana (refund)?',
      'answer':
          'Pesanan EcoMart yang belum diproses penjual dapat dibatalkan langsung melalui detail pesanan di menu EcoMart. Dana pembayaran menggunakan EcoCash Wallet akan dikembalikan otomatis ke saldo utama Anda.',
    },
  ];

  Map<String, Map<String, String>> get _defaultLegalDocs => {
        'terms-of-service': {
          'title': 'Syarat dan Ketentuan (Terms of Service)',
          'updatedAt': 'Berlaku sejak November 2026',
          'content':
              '1. Pengguna wajib mendaftarkan identitas yang sah serta menjaga kerahasiaan kata sandi dan kode QR kredensial akun EcoCash.\n'
              '2. Penyetoran sampah ke Smart Container (RVM) maupun layanan EcoJemput wajib mematuhi klasifikasi material yang diterima (bebas limbah B3 dan cairan).\n'
              '3. Nilai konversi rupiah dan poin karbon dihitung berdasarkan bobot/jumlah terverifikasi oleh sensor mesin atau penimbangan resmi mitra.\n'
              '4. EcoCash berhak menangguhkan akun apabila ditemukan indikasi manipulasi sensor mesin atau penyalahgunaan voucher.',
        },
        'privacy-policy': {
          'title': 'Kebijakan Privasi (Privacy Policy)',
          'updatedAt': 'Berlaku sejak November 2026',
          'content':
              '1. Data yang Dikumpulkan: Nama, email, nomor telepon, alamat penjemputan, koordinat lokasi saat mencari titik setor terdekat, serta riwayat transaksi daur ulang.\n'
              '2. Penggunaan Data: Digunakan secara eksklusif untuk memproses penjemputan sampah, pencairan saldo EcoCash Wallet, perhitungan dampak pengurangan karbon (CO2e), dan dukungan pelanggan.\n'
              '3. Keamanan Data: Seluruh komunikasi API terenkripsi dan kredensial pengguna tidak pernah dibagikan kepada pihak ketiga di luar kebutuhan pemrosesan pembayaran resmi.',
        },
        'community-guidelines': {
          'title': 'Panduan Komunitas EcoCash',
          'updatedAt': 'Berlaku sejak November 2026',
          'content':
              '1. Pilah dan bersihkan kemasan sebelum disetor demi menjaga kualitas bahan baku daur ulang dan kebersihan lingkungan sekitar Smart Container.\n'
              '2. Berikan ulasan yang jujur, santun, dan konstruktif pada transaksi EcoMart maupun layanan kurir mitra.\n'
              '3. Laporkan segera apabila menemukan fasilitas mesin yang penuh atau mengalami gangguan agar warga lain tetap dapat memanfaatkannya.',
        },
      };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _loadAllSupportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSupportData() async {
    await Future.wait([
      _fetchFaqs(),
      _fetchMaterials(),
      _fetchTickets(),
      _fetchSystemAnnouncements(),
      _fetchBotTree(),
      _fetchLegalDocuments(),
    ]);
  }

  // ============================================================
  // 1. FETCH FAQ + KATEGORI DINAMIS DARI BACKEND
  // ============================================================

  Future<void> _fetchFaqs() async {
    setState(() => _isLoadingFaqs = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.getFaqs}?limit=100'),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = _extractList(decoded);
        final source = list.isNotEmpty ? list : _fallbackFaqs;

        if (mounted) {
          setState(() {
            _faqs = source;
            _dynamicCategories = _buildCategoriesFromFaqs(list);
          });
        }
      } else if (mounted) {
        setState(() {
          _faqs = _fallbackFaqs;
          _dynamicCategories = _defaultProblemCategories;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _faqs = _fallbackFaqs;
          _dynamicCategories = _defaultProblemCategories;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingFaqs = false);
    }
  }

  List _buildCategoriesFromFaqs(List backendFaqs) {
    if (backendFaqs.isEmpty) return _defaultProblemCategories;

    final Set<String> uniqueCats = {};
    for (final item in backendFaqs) {
      final raw = (item['category'] ?? '').toString().trim();
      if (raw.isNotEmpty) uniqueCats.add(raw);
    }

    if (uniqueCats.isEmpty) return _defaultProblemCategories;

    return uniqueCats.map((catName) {
      final lower = catName.toLowerCase();
      IconData icon = Icons.help_outline_rounded;
      Color color = primaryNavy;
      Color bg = const Color(0xFFE2E8F0);
      String subtitle = 'Panduan & solusi terkait $catName';

      if (lower.contains('akun') || lower.contains('keamanan') || lower.contains('login')) {
        icon = Icons.shield_outlined;
        color = const Color(0xFF2563EB);
        bg = const Color(0xFFDBEAFE);
        subtitle = 'Verifikasi, kata sandi & keamanan akun';
      } else if (lower.contains('bayar') ||
          lower.contains('saldo') ||
          lower.contains('wallet') ||
          lower.contains('transaksi')) {
        icon = Icons.account_balance_wallet_outlined;
        color = ecoGreen;
        bg = const Color(0xFFDCFCE7);
        subtitle = 'Saldo EcoCash, pencairan & riwayat transaksi';
      } else if (lower.contains('mesin') ||
          lower.contains('teknis') ||
          lower.contains('error') ||
          lower.contains('kendala')) {
        icon = Icons.build_circle_outlined;
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEE2E2);
        subtitle = 'Penanganan error mesin & troubleshooting';
      } else if (lower.contains('setor') ||
          lower.contains('jemput') ||
          lower.contains('fitur') ||
          lower.contains('layanan')) {
        icon = Icons.recycling_rounded;
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFEF3C7);
        subtitle = 'Panduan setor sampah & layanan aplikasi';
      }

      return {
        'key': catName,
        'title': catName,
        'subtitle': subtitle,
        'icon': icon,
        'color': color,
        'bg': bg,
      };
    }).toList();
  }

  Future<void> _fetchMaterials() async {
    setState(() => _isLoadingMaterials = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getRecycleMaterialGuides),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = _extractList(decoded);
        if (mounted) setState(() => _materials = list);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMaterials = false);
    }
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoadingTickets = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getMyTickets),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = _extractList(decoded);
        if (mounted) setState(() => _tickets = list);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingTickets = false);
    }
  }

  Future<void> _fetchSystemAnnouncements() async {
    final List combinedAlerts = [];

    try {
      final newsRes = await http.get(
        Uri.parse('${ApiConfig.getPublicNews}?category=SYSTEM&limit=5'),
        headers: ApiConfig.headers,
      );
      if (newsRes.statusCode == 200) {
        final newsList = _extractList(jsonDecode(newsRes.body));
        for (final item in newsList) {
          combinedAlerts.add({
            'title': item['title'] ?? 'Pengumuman Sistem',
            'body': item['excerpt'] ?? item['content'] ?? '',
          });
        }
      }
    } catch (_) {}

    try {
      final notifRes = await http.get(
        Uri.parse(ApiConfig.getNotifications),
        headers: ApiConfig.headers,
      );
      if (notifRes.statusCode == 200) {
        final list = _extractList(jsonDecode(notifRes.body));
        for (final n in list) {
          final type = (n['type'] ?? '').toString().toUpperCase();
          if (type == 'SYSTEM' || type == 'CONTAINER_ALERT') {
            combinedAlerts.add({
              'title': n['title'] ?? 'Informasi Layanan',
              'body': n['body'] ?? '',
            });
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _systemAlerts = combinedAlerts);
    }
  }

  Future<void> _fetchLegalDocuments() async {
    setState(() => _isLoadingLegal = true);
    final docs = Map<String, Map<String, String>>.from(_defaultLegalDocs);

    for (final slug in ['terms-of-service', 'privacy-policy', 'community-guidelines']) {
      try {
        final res = await http.get(
          Uri.parse(ApiConfig.getPublicNewsBySlug(slug)),
          headers: ApiConfig.headers,
        );
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final data = decoded is Map ? decoded['data'] : null;
          if (data is Map && data['content'] != null) {
            docs[slug] = {
              'title': data['title']?.toString() ?? docs[slug]!['title']!,
              'updatedAt': 'Diperbarui dari server EcoCash',
              'content': data['content'].toString(),
            };
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _legalDocs = docs;
        _isLoadingLegal = false;
      });
    }
  }

  Future<void> _fetchBotTree() async {
    setState(() => _isLoadingBot = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.getBotTree),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map ? decoded['data'] : null;
        if (data is Map && data.isNotEmpty) {
          _botTree = Map.from(data);
        }
      }
    } catch (_) {}

    if (_botTree.isEmpty) {
      _botTree = _defaultBotTree;
    }

    if (mounted) {
      setState(() {
        _isLoadingBot = false;
        if (_chatMessages.isEmpty) {
          _pushBotNode(_initialBotNodeKey);
        }
      });
    }
  }

  Map get _defaultBotTree => {
        'root': {
          'message':
              'Halo Warga EcoCash! Saya asisten virtual bantuan. Topik apa yang sedang Anda butuhkan?',
          'options': [
            {'label': 'Cara Setor & Tukar Sampah', 'next': 'setor_sampah'},
            {'label': 'Kendala Saldo & Penarikan', 'next': 'saldo_masalah'},
            {'label': 'Mesin RVM Error / Penuh', 'next': 'mesin_error'},
            {'label': 'Hubungkan ke Agen / Buat Tiket', 'next': 'buat_tiket'},
          ],
        },
        'setor_sampah': {
          'message':
              'Anda bisa menyetor via Smart Container (menu EcoDrop -> Pindai QR) atau memesan kurir jemput ke rumah lewat menu EcoJemput.',
          'options': [
            {'label': 'Sampah apa saja yang diterima?', 'next': 'jenis_sampah'},
            {'label': 'Kembali ke Menu Utama', 'next': 'root'},
          ],
        },
        'jenis_sampah': {
          'message':
              'Mesin menerima botol plastik PET bening/berwarna, kaleng aluminium, serta kardus/kertas kering lewat layanan EcoJemput. Pastikan botol kosong dan tidak remuk.',
          'options': [
            {'label': 'Kembali ke Menu Utama', 'next': 'root'},
          ],
        },
        'saldo_masalah': {
          'message':
              'Saldo otomatis bertambah setelah sesi setor dikonfirmasi. Jika saldo belum masuk dalam 15 menit, silakan buat tiket pengaduan dengan melampirkan bukti transaksi.',
          'options': [
            {'label': 'Buat Tiket Pengaduan Sekarang', 'next': 'buat_tiket'},
            {'label': 'Kembali ke Menu Utama', 'next': 'root'},
          ],
        },
        'mesin_error': {
          'message':
              'Mohon maaf atas ketidaknyamanannya. Laporkan kode/lokasi mesin melalui formulir tiket agar teknisi lapangan kami segera melakukan penanganan.',
          'options': [
            {'label': 'Laporkan Mesin Rusak', 'next': 'buat_tiket'},
            {'label': 'Kembali ke Menu Utama', 'next': 'root'},
          ],
        },
        'buat_tiket': {
          'message':
              'Silakan ketuk tombol "Buka Formulir Tiket" di bawah ini untuk mengirim laporan lengkap beserta foto bukti ke tim dukungan kami.',
          'options': [
            {'label': 'Kembali ke Menu Utama', 'next': 'root'},
          ],
        },
      };

  String get _initialBotNodeKey {
    if (_botTree.isEmpty) return 'root';
    for (final candidate in ['root', 'main', 'welcome', 'start', 'menu_utama']) {
      if (_botTree.containsKey(candidate)) return candidate;
    }
    return _botTree.keys.first.toString();
  }

  void _pushBotNode(String nodeKey) {
    if (_botTree.isEmpty) return;

    final dynamic rawNode =
        _botTree[nodeKey] ?? _botTree[_initialBotNodeKey] ?? _botTree.values.first;
    if (rawNode is! Map) return;

    final String msg = rawNode['message']?.toString() ??
        rawNode['text']?.toString() ??
        'Halo! Silakan pilih topik bantuan di bawah ini:';
    final List options = rawNode['options'] is List ? rawNode['options'] : [];

    _chatMessages.add({
      'isBot': true,
      'text': msg,
      'options': options,
      'showTicketAction': nodeKey == 'buat_tiket' || options.isEmpty,
    });
  }

  void _onSelectBotOption(Map option) {
    final String label = option['label']?.toString() ?? '';
    final String action = (option['action'] ?? '').toString().toUpperCase();
    final String url = option['url']?.toString() ?? '';
    final String nextKey = option['next']?.toString() ?? _initialBotNodeKey;

    setState(() {
      _chatMessages.add({'isBot': false, 'text': label});

      if (action == 'LINK' && url.isNotEmpty) {
        _chatMessages.add({
          'isBot': true,
          'text': 'Membuka tautan panduan: $url',
          'options': [
            {'label': 'Kembali ke Menu Utama', 'next': _initialBotNodeKey},
          ],
          'showTicketAction': false,
        });
      } else {
        _pushBotNode(nextKey);
      }
    });

    if (action == 'LINK' && url.isNotEmpty) {
      final targetUrl = url.startsWith('http') ? url : 'https://ecocash.id$url';
      _launchExternal(targetUrl);
    }
  }

  List _extractList(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType().map((e) => Map.from(e)).toList();
    }
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is List) {
        return data.whereType().map((e) => Map.from(e)).toList();
      }
      if (data is Map) {
        for (final key in ['items', 'faqs', 'tickets', 'materials', 'notifications', 'news']) {
          if (data[key] is List) {
            return (data[key] as List)
                .whereType()
                .map((e) => Map.from(e))
                .toList();
          }
        }
      }
    }
    return [];
  }

  List get _filteredFaqs {
    return _faqs.where((faq) {
      final q = (faq['question'] ?? '').toString().toLowerCase();
      final a = (faq['answer'] ?? '').toString().toLowerCase();
      final cat = (faq['category'] ?? 'Umum').toString();

      final matchCategory = _selectedFaqCategory == 'Semua' ||
          cat.toLowerCase() == _selectedFaqCategory.toLowerCase() ||
          cat.toLowerCase().contains(_selectedFaqCategory.toLowerCase()) ||
          _selectedFaqCategory.toLowerCase().contains(cat.toLowerCase());

      final matchKeyword = _searchKeyword.isEmpty ||
          q.contains(_searchKeyword) ||
          a.contains(_searchKeyword) ||
          cat.toLowerCase().contains(_searchKeyword);

      return matchCategory && matchKeyword;
    }).toList();
  }

  bool _isMaterialAccepted(Map m) {
    if (m['isAccepted'] == true) return true;
    final rawStatus = (m['status'] ?? m['statusLabel'] ?? 'ACCEPTED')
        .toString()
        .trim()
        .toUpperCase();
    return rawStatus == 'ACCEPTED' ||
        rawStatus == 'DITERIMA' ||
        rawStatus == 'APPROVED' ||
        rawStatus == 'TRUE';
  }

  List get _filteredMaterials {
    return _materials.where((m) {
      final isAccepted = _isMaterialAccepted(m);
      final name = (m['name'] ?? '').toString().toLowerCase();
      final cat = (m['category'] ?? '').toString().toLowerCase();

      final matchStatus = _materialStatusFilter == 'ALL' ||
          (_materialStatusFilter == 'ACCEPTED' && isAccepted) ||
          (_materialStatusFilter == 'REJECTED' && !isAccepted);

      final matchSearch = _searchKeyword.isEmpty ||
          name.contains(_searchKeyword) ||
          cat.contains(_searchKeyword);

      return matchStatus && matchSearch;
    }).toList();
  }

  MediaType _resolveAttachmentMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    } else if (lower.endsWith('.gif')) {
      return MediaType('image', 'gif');
    } else if (lower.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }
    return MediaType('image', 'jpeg');
  }

  // ============================================================
  // 2. MODAL KIRIM TIKET PENGADUAN (POST /tickets + MULTIPART)
  // ============================================================

  void _openCreateTicketSheet({String initialCategory = 'OTHER'}) {
    final subjectController = TextEditingController();
    final descController = TextEditingController();
    String category = initialCategory;
    String priority = 'MEDIUM';
    XFile? selectedFile;
    Uint8List? selectedBytes;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> pickAttachment() async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 80,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                setModalState(() {
                  selectedFile = picked;
                  selectedBytes = bytes;
                });
              }
            }

            Future<void> submitTicket() async {
              final subject = subjectController.text.trim();
              final description = descController.text.trim();

              if (subject.isEmpty || description.isEmpty) {
                _showSnack('Judul dan kronologi kendala wajib diisi.', isError: true);
                return;
              }

              setModalState(() => isSubmitting = true);

              try {
                final request = http.MultipartRequest(
                  'POST',
                  Uri.parse(ApiConfig.createTicket),
                );

                if (ApiConfig.hasToken) {
                  request.headers['Authorization'] =
                      'Bearer ${ApiConfig.userToken!.trim()}';
                }
                request.headers['Accept'] = 'application/json';

                request.fields['category'] = category;
                request.fields['priority'] = priority;
                request.fields['subject'] = subject;
                request.fields['description'] = description;

                if (selectedFile != null && selectedBytes != null) {
                  final filename = selectedFile!.name.isNotEmpty
                      ? selectedFile!.name
                      : 'attachment.jpg';
                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'attachment',
                      selectedBytes!,
                      filename: filename,
                      contentType: _resolveAttachmentMediaType(filename),
                    ),
                  );
                }

                final streamed = await request.send();
                final response = await http.Response.fromStream(streamed);
                final decoded = jsonDecode(response.body);

                if (response.statusCode == 200 || response.statusCode == 201) {
                  if (modalCtx.mounted) Navigator.pop(modalCtx);
                  _showSnack('Tiket pengaduan berhasil dikirim ke tim support!');
                  _tabController.animateTo(2);
                  await _fetchTickets();
                } else {
                  final msg = decoded is Map
                      ? (decoded['message']?.toString() ?? 'Gagal mengirim tiket')
                      : 'Gagal mengirim tiket';
                  _showSnack(msg, isError: true);
                }
              } catch (e) {
                _showSnack('Terjadi kesalahan koneksi: $e', isError: true);
              } finally {
                if (ctx.mounted) setModalState(() => isSubmitting = false);
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kirim Tiket Pengaduan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sertakan detail kendala & bukti tangkapan layar agar cepat diproses.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text('Kategori Kendala',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField(
                        initialValue: category,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: 'MACHINE_BROKEN',
                            child: Text('Mesin Smart Container (RVM) Rusak'),
                          ),
                          DropdownMenuItem(
                            value: 'WEIGHING_DISCREPANCY',
                            child: Text('Selisih Berat / Poin Setoran'),
                          ),
                          DropdownMenuItem(
                            value: 'WITHDRAWAL_ISSUE',
                            child: Text('Kendala Saldo / Top-Up / Transaksi'),
                          ),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('Akun, Aplikasi & Lainnya'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Tingkat Urgensi',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField(
                        initialValue: priority,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'LOW', child: Text('Rendah (Pertanyaan Umum)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Sedang (Kendala Layanan)')),
                          DropdownMenuItem(value: 'HIGH', child: Text('Tinggi (Transaksi / Saldo)')),
                          DropdownMenuItem(value: 'URGENT', child: Text('Mendesak (Akun / Mesin Mati)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => priority = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Judul Laporan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: subjectController,
                        decoration: _inputDecoration(
                          hint: 'Contoh: Saldo belum masuk setelah setor di Stasiun Bandung',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Kronologi & Detail Masalah',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          hint: 'Jelaskan waktu kejadian, lokasi mesin, atau nomor pesanan...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Lampiran Bukti / Screenshot (Opsional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: pickAttachment,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_file_rounded, color: textDark, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selectedFile != null
                                      ? selectedFile!.name
                                      : 'Pilih foto atau screenshot dari galeri',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selectedFile != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selectedFile != null ? ecoGreen : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              if (selectedFile != null)
                                GestureDetector(
                                  onTap: () => setModalState(() {
                                    selectedFile = null;
                                    selectedBytes = null;
                                  }),
                                  child: const Icon(Icons.close, size: 18, color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandYellow,
                            foregroundColor: textDark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: textDark,
                                  ),
                                )
                              : const Text(
                                  'Kirim Tiket Pengaduan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 3. UI UTAMA & 4 TAB TERINTEGRASI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: Column(
        children: [
          _buildHeaderWithSearch(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFaqAndEducationTab(),
                _buildChatbotAndSupportTab(),
                _buildTicketsAndStatusTab(),
                _buildLegalAndPolicyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithSearch() {
    return Container(
      decoration: const BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pusat Bantuan & Edukasi',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: textDark,
                          ),
                        ),
                        Text(
                          'Solusi cepat, panduan daur ulang & layanan pengaduan',
                          style: TextStyle(fontSize: 11, color: Color(0xFF3F3F46)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchKeyword = val.trim().toLowerCase();
                    });
                    if (_tabController.index != 0 && val.trim().isNotEmpty) {
                      _tabController.animateTo(0);
                    }
                  },
                  style: const TextStyle(fontSize: 13, color: textDark),
                  decoration: InputDecoration(
                    hintText: 'Cari solusi (misal: ganti sandi, saldo, botol PET)...',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchKeyword = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: textDark,
              unselectedLabelColor: const Color(0xFF52525B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              indicatorColor: textDark,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              tabs: [
                const Tab(text: 'FAQ & Edukasi'),
                const Tab(text: 'Asisten & Kontak'),
                Tab(
                  text: _tickets.isEmpty
                      ? 'Tiket & Status'
                      : 'Tiket Saya (${_tickets.length})',
                ),
                const Tab(text: 'Legal & Kebijakan'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqAndEducationTab() {
    final faqs = _filteredFaqs;
    final materials = _filteredMaterials;
    final categories = _dynamicCategories.isNotEmpty
        ? _dynamicCategories
        : _defaultProblemCategories;

    return RefreshIndicator(
      onRefresh: _loadAllSupportData,
      color: textDark,
      backgroundColor: brandYellow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kategori Masalah Utama',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
              ),
              if (_selectedFaqCategory != 'Semua')
                GestureDetector(
                  onTap: () => setState(() => _selectedFaqCategory = 'Semua'),
                  child: const Text(
                    'Reset Filter',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryNavy),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final bool isSelected = _selectedFaqCategory == cat['key'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFaqCategory =
                        isSelected ? 'Semua' : cat['key'].toString();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? textDark : Colors.grey.shade200,
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cat['bg'] as Color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          color: cat['color'] as Color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['title'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat['subtitle'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            _selectedFaqCategory == 'Semua'
                ? 'Pertanyaan Sering Diajukan (FAQ)'
                : 'FAQ: $_selectedFaqCategory',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
          ),
          const SizedBox(height: 10),
          if (_isLoadingFaqs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: textDark),
              ),
            )
          else if (faqs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Tidak ditemukan artikel bantuan untuk kata kunci tersebut.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _openCreateTicketSheet(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandYellow,
                      foregroundColor: textDark,
                      elevation: 0,
                    ),
                    child: const Text('Tanyakan ke Tim Support',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            ...faqs.map((faq) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: Text(
                      faq['question']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        faq['category']?.toString() ?? 'Panduan Umum',
                        style: const TextStyle(
                          fontSize: 10,
                          color: ecoGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq['answer']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          const Text(
            'Edukasi Pemilahan Material Sampah',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pastikan jenis sampah sesuai standar agar diterima oleh Smart Container & Mitra.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFilterChip('Semua', 'ALL'),
              const SizedBox(width: 8),
              _buildFilterChip('Diterima', 'ACCEPTED'),
              const SizedBox(width: 8),
              _buildFilterChip('Ditolak', 'REJECTED'),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingMaterials)
            const Center(child: CircularProgressIndicator(color: textDark))
          else if (materials.isEmpty)
            _buildDefaultMaterialGuideCards()
          else
            ...materials.map((m) {
              final isAccepted = _isMaterialAccepted(m);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isAccepted
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isAccepted ? ecoGreen : const Color(0xFFDC2626),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['name']?.toString() ?? 'Material',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textDark,
                            ),
                          ),
                          if (m['reason'] != null &&
                              m['reason'].toString().trim().isNotEmpty)
                            Text(
                              m['reason'].toString(),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAccepted
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAccepted ? 'DITERIMA' : 'DITOLAK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isAccepted ? ecoGreen : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool active = _materialStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _materialStatusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? textDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? textDark : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? brandYellow : textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultMaterialGuideCards() {
    final defaults = [
      {
        'name': 'Botol Plastik PET (Air Mineral & Minuman)',
        'status': 'ACCEPTED',
        'reason': 'Kosongkan isi cairan, lepas segel plastik berlebih, dan tidak penyok.',
      },
      {
        'name': 'Kaleng Aluminium Minuman',
        'status': 'ACCEPTED',
        'reason': 'Pastikan bersih dari sisa cairan manis.',
      },
      {
        'name': 'Botol Kaca, Baterai & Limbah B3',
        'status': 'REJECTED',
        'reason': 'Berisiko merusak sensor dan mekanisme pencacah Smart Container.',
      },
    ];

    return Column(
      children: defaults
          .where((d) =>
              _materialStatusFilter == 'ALL' || d['status'] == _materialStatusFilter)
          .map((m) {
        final isAccepted = m['status'] == 'ACCEPTED';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAccepted ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isAccepted ? ecoGreen : const Color(0xFFDC2626),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['name']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                    Text(m['reason']!,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChatbotAndSupportTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandYellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: textDark, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asisten Virtual EcoCash',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: textDark,
                          ),
                        ),
                        Text(
                          'Online • Jawaban otomatis instan 24/7',
                          style: TextStyle(fontSize: 11, color: ecoGreen, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _chatMessages.clear();
                        _pushBotNode(_initialBotNodeKey);
                      });
                    },
                    child: const Text('Ulangi',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryNavy)),
                  ),
                ],
              ),
              const Divider(height: 22),
              if (_isLoadingBot)
                const Center(child: CircularProgressIndicator(color: textDark))
              else
                ..._chatMessages.map((msg) {
                  final bool isBot = msg['isBot'] == true;
                  final List options = msg['options'] is List ? msg['options'] : [];
                  final bool showTicketAction = msg['showTicketAction'] == true;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment:
                          isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isBot ? surfaceBg : textDark,
                            borderRadius: BorderRadius.circular(16),
                            border: isBot ? Border.all(color: Colors.grey.shade200) : null,
                          ),
                          child: Text(
                            msg['text']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isBot ? textDark : Colors.white,
                            ),
                          ),
                        ),
                        if (isBot && options.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: options.map((opt) {
                              if (opt is! Map) return const SizedBox.shrink();
                              return ActionChip(
                                backgroundColor: brandYellow.withValues(alpha: 0.35),
                                side: const BorderSide(color: Color(0xFFEAB308)),
                                label: Text(
                                  opt['label']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                                onPressed: () => _onSelectBotOption(opt),
                              );
                            }).toList(),
                          ),
                        ],
                        if (isBot && showTicketAction) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openCreateTicketSheet(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandYellow,
                              foregroundColor: textDark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit_document, size: 16),
                            label: const Text('Buka Formulir Tiket',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Hubungi Tim Customer Support',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
        ),
        const SizedBox(height: 10),
        _buildSupportChannelCard(
          icon: Icons.confirmation_number_rounded,
          iconBg: brandYellow,
          title: 'Kirim Tiket Pengaduan Resmi',
          subtitle: 'Lampirkan foto bukti & pantau progres penanganan admin',
          buttonText: 'Buat Tiket',
          onTap: () => _openCreateTicketSheet(),
        ),
        const SizedBox(height: 10),
        _buildSupportChannelCard(
          icon: Icons.chat_rounded,
          iconBg: const Color(0xFFDCFCE7),
          iconColor: ecoGreen,
          title: 'WhatsApp Helpdesk EcoCash',
          subtitle: '$_officialWhatsappDisplay • Senin - Minggu',
          buttonText: 'Chat WA',
          onTap: () => _launchExternal(
            'https://wa.me/$_officialWhatsappRaw?text=Halo%20Admin%20EcoCash%2C%20saya%20membutuhkan%20bantuan%20terkait%20aplikasi.',
          ),
        ),
        const SizedBox(height: 10),
        _buildSupportChannelCard(
          icon: Icons.phone_in_talk_rounded,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          title: 'Pusat Panggilan (Call Center)',
          subtitle: _officialWhatsappDisplay,
          buttonText: 'Telepon',
          onTap: () => _launchExternal('tel:+$_officialWhatsappRaw'),
        ),
        const SizedBox(height: 10),
        _buildSupportChannelCard(
          icon: Icons.email_outlined,
          iconBg: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
          title: 'Email Layanan Pelanggan',
          subtitle: _officialEmail,
          buttonText: 'Kirim Email',
          onTap: () => _launchExternal(
            'mailto:$_officialEmail?subject=Bantuan%20Aplikasi%20EcoCash%20Indonesia',
          ),
        ),
      ],
    );
  }

  Widget _buildSupportChannelCard({
    required IconData icon,
    required Color iconBg,
    Color iconColor = textDark,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: textDark,
              foregroundColor: brandYellow,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(buttonText,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsAndStatusTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchTickets();
        await _fetchSystemAnnouncements();
      },
      color: textDark,
      backgroundColor: brandYellow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _systemAlerts.isEmpty
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _systemAlerts.isEmpty
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFFCD34D),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _systemAlerts.isEmpty
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: _systemAlerts.isEmpty ? ecoGreen : const Color(0xFFD97706),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _systemAlerts.isEmpty
                            ? 'Semua Layanan Operasional Normal'
                            : (_systemAlerts.first['title']?.toString() ??
                                'Informasi Pemeliharaan Sistem'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _systemAlerts.isEmpty
                            ? 'Server API, Dompet EcoCash, dan jaringan Smart Container berjalan normal tanpa gangguan.'
                            : (_systemAlerts.first['body']?.toString() ?? ''),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF3F3F46)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Laporan / Tiket Saya',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
              ),
              ElevatedButton.icon(
                onPressed: () => _openCreateTicketSheet(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  foregroundColor: textDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Buat Tiket',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingTickets)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: textDark),
              ),
            )
          else if (_tickets.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 46, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum Ada Tiket Pengaduan',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Jika menemukan kendala mesin, selisih timbangan, atau transaksi, laporkan di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ..._tickets.map((ticket) => _buildTicketCard(ticket)),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map ticket) {
    final String status = (ticket['status'] ?? 'OPEN').toString().toUpperCase();
    final String category = (ticket['category'] ?? 'OTHER').toString().toUpperCase();
    final String? adminNotes = ticket['adminNotes']?.toString();

    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeText = const Color(0xFFD97706);
    if (status == 'RESOLVED' || status == 'CLOSED') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = ecoGreen;
    } else if (status == 'IN_PROGRESS') {
      badgeBg = const Color(0xFFDBEAFE);
      badgeText = const Color(0xFF2563EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${ticket['id'] ?? '-'} • ${_formatTicketCategory(category)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ticket['subject']?.toString() ?? 'Laporan Kendala',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ticket['description']?.toString() ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
          ),
          if (adminNotes != null && adminNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tanggapan Tim Bantuan:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    adminNotes,
                    style: const TextStyle(fontSize: 12, color: textDark),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTicketCategory(String category) {
    switch (category) {
      case 'MACHINE_BROKEN':
        return 'Mesin RVM';
      case 'WEIGHING_DISCREPANCY':
        return 'Selisih Timbangan';
      case 'WITHDRAWAL_ISSUE':
        return 'Saldo & Transaksi';
      default:
        return 'Umum';
    }
  }

  Widget _buildLegalAndPolicyTab() {
    if (_isLoadingLegal) {
      return const Center(child: CircularProgressIndicator(color: textDark));
    }

    final docs = _legalDocs.isNotEmpty ? _legalDocs : _defaultLegalDocs;
    final terms = docs['terms-of-service']!;
    final privacy = docs['privacy-policy']!;
    final community = docs['community-guidelines']!;

    return RefreshIndicator(
      onRefresh: _fetchLegalDocuments,
      color: textDark,
      backgroundColor: brandYellow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildLegalCard(
            icon: Icons.gavel_rounded,
            title: terms['title']!,
            updatedAt: terms['updatedAt']!,
            content: terms['content']!,
          ),
          const SizedBox(height: 12),
          _buildLegalCard(
            icon: Icons.privacy_tip_outlined,
            title: privacy['title']!,
            updatedAt: privacy['updatedAt']!,
            content: privacy['content']!,
          ),
          const SizedBox(height: 12),
          _buildLegalCard(
            icon: Icons.groups_outlined,
            title: community['title']!,
            updatedAt: community['updatedAt']!,
            content: community['content']!,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard({
    required IconData icon,
    required String title,
    required String updatedAt,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandYellow.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: textDark, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: textDark,
                      ),
                    ),
                    Text(
                      updatedAt,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      filled: true,
      fillColor: surfaceBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: textDark, width: 1.5),
      ),
    );
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? Colors.red.shade700 : ecoGreen,
          content: Text(message),
        ),
      );
  }
}