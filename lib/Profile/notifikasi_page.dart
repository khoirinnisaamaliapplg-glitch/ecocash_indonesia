import 'dart:convert';
import 'package:ecocash_indonesia/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

typedef NotifMap = Map<String, dynamic>;

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color primaryNavy = Color(0xFF0F2C59);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  bool _isLoading = true;
  bool _onlyUnread = false;
  List<NotifMap> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final url = _onlyUnread
          ? '${ApiConfig.getNotifications}?isRead=false&limit=50'
          : '${ApiConfig.getNotifications}?limit=50';
      final res = await http.get(Uri.parse(url), headers: ApiConfig.headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final dynamic raw = body['data'];
        final List list = raw is List
            ? raw
            : (raw is Map && raw['notifications'] is List
                ? raw['notifications']
                : (raw is Map && raw['items'] is List ? raw['items'] : []));
        if (mounted) {
          setState(() {
            _items = list.map((e) => NotifMap.from(e as Map)).toList();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final res = await http.patch(
        Uri.parse(ApiConfig.markAllNotificationsRead),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        await _fetchNotifications();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua notifikasi ditandai sudah dibaca'), backgroundColor: ecoGreen),
        );
      }
    } catch (_) {}
  }

  Future<void> _markSingleRead(NotifMap item) async {
    final int? id = int.tryParse((item['id'] ?? '').toString());
    if (id != null && item['isRead'] != true) {
      try {
        await http.patch(
          Uri.parse(ApiConfig.markNotificationRead(id)),
          headers: ApiConfig.headers,
        );
        if (mounted) {
          setState(() => item['isRead'] = true);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (item['title'] ?? 'Notifikasi EcoCash').toString(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark),
            ),
            const SizedBox(height: 8),
            Text(
              (item['body'] ?? item['message'] ?? '-').toString(),
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandYellow, foregroundColor: textDark, elevation: 0),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int unreadCount = _items.where((e) => e['isRead'] != true).length;

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: brandYellow,
        elevation: 0,
        title: const Text('Notifikasi', style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Baca Semua', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: !_onlyUnread,
                  selectedColor: brandYellow,
                  onSelected: (_) {
                    setState(() => _onlyUnread = false);
                    _fetchNotifications();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Belum Dibaca'),
                  selected: _onlyUnread,
                  selectedColor: brandYellow,
                  onSelected: (_) {
                    setState(() => _onlyUnread = true);
                    _fetchNotifications();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text('Belum ada notifikasi', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final bool isRead = item['isRead'] == true;
                            return Material(
                              color: isRead ? Colors.white : const Color(0xFFFEFCE8),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _markSingleRead(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          color: isRead ? const Color(0xFFF1F5F9) : const Color(0xFFFEF08A),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.notifications_active_rounded,
                                          size: 20,
                                          color: isRead ? Colors.grey : textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (item['title'] ?? 'Info EcoCash').toString(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                                color: textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (item['body'] ?? item['message'] ?? '').toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 6, left: 6),
                                          decoration: const BoxDecoration(color: ecoGreen, shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
