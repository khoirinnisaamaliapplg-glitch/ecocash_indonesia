import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../ipconfig.dart';

class ChatDriverPage extends StatefulWidget {
  final dynamic jobId;
  final String driverName;
  final String? driverPhone;
  final String? vehicleInfo;
  final String orderStatus;

  const ChatDriverPage({
    super.key,
    required this.jobId,
    required this.driverName,
    this.driverPhone,
    this.vehicleInfo,
    required this.orderStatus,
  });

  @override
  State<ChatDriverPage> createState() => _ChatDriverPageState();
}

class _ChatDriverPageState extends State<ChatDriverPage> {
  final Color primary = const Color(0xff0BCFD1);
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  Timer? _pollingTimer;
  bool _isSending = false;
  String? _roomId;
  int? _userId;

  final List<String> _quickTemplates = [
    "Halo Pak, posisi sudah di mana?",
    "Sampah sudah siap di depan pagar.",
    "Bisa tolong klakson kalau sudah sampai?",
    "Saya tunggu di titik lokasi ya Pak.",
  ];

  @override
  void initState() {
    super.initState();
    _initChatRoom();
    _startMessagePolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildUrl(String path) {
    String base = '';
    try {
      base = ApiConfig.baseUrl;
    } catch (_) {}

    if (base.isEmpty) {
      try {
        final sample = ApiConfig.getUserAddresses;
        final uri = Uri.parse(sample);
        base = "${uri.scheme}://${uri.host}:${uri.port}/api/v1";
      } catch (_) {
        base = "http://localhost:5000/api/v1";
      }
    }

    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = path.startsWith('/') ? path : '/$path';

    if (cleanPath.startsWith('/api/v1')) {
      final origin = Uri.parse(cleanBase);
      return "${origin.scheme}://${origin.host}:${origin.port}$cleanPath";
    }

    if (!cleanBase.endsWith('/api/v1')) {
      return '$cleanBase/api/v1$cleanPath';
    }

    return '$cleanBase$cleanPath';
  }

  Future<void> _initChatRoom() async {
    setState(() {
      _messages = [
        {
          'id': 'sys-init',
          'sender': 'system',
          'text': 'Kurir ${widget.driverName} telah mengambil tugas penjemputan sampah Anda.',
          'time': 'Sistem',
        },
      ];
    });

    try {
      final uri = Uri.parse(_buildUrl('/chat/job/${widget.jobId}'));
      final res = await http.get(uri, headers: ApiConfig.headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? decoded;

        if (data is Map) {
          _roomId = data['id']?.toString();
          _userId = _toInt(data['userId']);

          final rawMessages = data['messages'];
          if (rawMessages is List && mounted) {
            _parseMessages(rawMessages);
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal inisialisasi chat room: $e");
    }
  }

  void _startMessagePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;

      if (_roomId == null) {
        await _initChatRoom();
        return;
      }

      try {
        final uri = Uri.parse(_buildUrl('/chat/history/$_roomId'));
        final res = await http.get(uri, headers: ApiConfig.headers);

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final List list = decoded['data'] is List ? decoded['data'] : [];

          if (list.length != (_messages.length - 1) && mounted) {
            _parseMessages(list);
            _scrollToBottom();
          }
        }
      } catch (_) {}
    });
  }

  void _parseMessages(List rawList) {
    final List<Map<String, dynamic>> parsed = [
      {
        'id': 'sys-init',
        'sender': 'system',
        'text': 'Kurir ${widget.driverName} telah mengambil tugas penjemputan sampah Anda.',
        'time': 'Sistem',
      },
    ];

    for (var m in rawList) {
      if (m is! Map) continue;
      final String senderType = (m['senderType'] ?? m['senderRole'] ?? m['sender'] ?? '').toString().toUpperCase();
      final bool isUser = (senderType == 'REGULAR_USER' ||
          senderType == 'USER' ||
          senderType == 'CITIZEN' ||
          senderType == 'WARGA');

      parsed.add({
        'id': m['id']?.toString() ?? '',
        'sender': isUser ? 'warga' : 'driver',
        'text': (m['message'] ?? m['text'] ?? '').toString(),
        'time': _formatTime(m['createdAt']),
      });
    }

    setState(() {
      _messages = parsed;
    });
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _isSending) return;

    final now = DateTime.now();
    final localMsg = {
      'id': 'local-${now.millisecondsSinceEpoch}',
      'sender': 'warga',
      'text': cleanText,
      'time': "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
    };

    setState(() {
      _messages.add(localMsg);
      _isSending = true;
    });

    _msgController.clear();
    _scrollToBottom();

    try {
      if (_roomId == null) {
        final roomRes = await http.get(
          Uri.parse(_buildUrl('/chat/job/${widget.jobId}')),
          headers: ApiConfig.headers,
        );
        if (roomRes.statusCode == 200) {
          final rData = jsonDecode(roomRes.body);
          _roomId = (rData['data'] ?? rData)['id']?.toString();
          _userId ??= _toInt((rData['data'] ?? rData)['userId']);
        }
      }

      if (_roomId != null) {
        final response = await http.post(
          Uri.parse(_buildUrl('/chat/message')),
          headers: {
            ...ApiConfig.headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'roomId': _roomId,
            'senderId': _userId ?? 1,
            'message': cleanText,
            'senderType': 'REGULAR_USER',
          }),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Gagal mengirim pesan (${response.statusCode}): ${response.body}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal mengirim pesan chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim pesan: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(dynamic val) {
    if (val == null) return '';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return '';
    }
  }

  int? _toInt(dynamic val) {
    if (val is int) return val;
    return int.tryParse(val?.toString() ?? '');
  }

  void _callDriver() async {
    if (widget.driverPhone == null || widget.driverPhone!.isEmpty) return;
    final Uri telUri = Uri.parse("tel:${widget.driverPhone}");
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primary.withOpacity(0.15),
              radius: 18,
              child: const Icon(Icons.two_wheeler, color: Color(0xFF0F2C59), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.driverName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.vehicleInfo != null ? '${widget.vehicleInfo} • Driver Aktif' : 'Driver EcoCash Partner',
                    style: const TextStyle(fontSize: 11, color: Colors.teal),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.driverPhone != null && widget.driverPhone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.teal),
              tooltip: 'Telepon Driver',
              onPressed: _callDriver,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBanner(),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text("Belum ada pesan. Mulai obrolan dengan kurir.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final String sender = msg['sender'] ?? '';
                      final bool isMe = (sender == 'warga' || sender == 'user');
                      final bool isSystem = sender == 'system';

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg['text'] ?? '',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return _buildMessageBubble(msg['text'] ?? '', msg['time'] ?? '', isMe);
                    },
                  ),
          ),
          _buildQuickTemplates(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: primary.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Status: ${widget.orderStatus}. Koordinasikan titik temu sampah dengan kurir.',
              style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, String time, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white : Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 9,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTemplates() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickTemplates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final text = _quickTemplates[i];
          return ActionChip(
            label: Text(text, style: const TextStyle(fontSize: 11)),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onPressed: () => _sendMessage(text),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan untuk driver...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF4F6F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: primary,
              radius: 20,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: () => _sendMessage(_msgController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}