import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ecocash_indonesia/ipconfig.dart';
import '../voucher/voucher.dart';

class EcomerPage extends StatefulWidget {
  final String initialPath;
  final String? initialVoucherCode;
  final String? initialVoucherName;
  final String? initialStoreName;

  const EcomerPage({
    super.key,
    this.initialPath = '',
    this.initialVoucherCode,
    this.initialVoucherName,
    this.initialStoreName,
  });

  @override
  State<EcomerPage> createState() => _EcomerPageState();
}

class _EcomerPageState extends State<EcomerPage> {
  static const Color brandYellow = Color(0xFFFFE600);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color ecoGreen = Color(0xFF00AA13);
  static const Color surfaceBg = Color(0xFFF7F8FA);

  static const String _baseMarketplaceUrl = 'https://marketplace.ecocash.id';

  WebViewController? _controller;
  double _loadingProgress = 0;
  bool _isInitializing = true;
  bool _isPageLoading = false;
  bool _hasError = false;
  bool _sessionInjected = false;
  String _currentTitle = 'EcoMart Marketplace';
  Map<String, dynamic>? _cachedUser;

  String? _activeVoucherCode;
  String? _activeVoucherName;
  String? _activeStoreName;

  bool get _isMobileWebViewSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _targetUrl {
    if (widget.initialPath.isEmpty) return '$_baseMarketplaceUrl/';
    if (widget.initialPath.startsWith('http')) return widget.initialPath;
    final cleanPath = widget.initialPath.startsWith('/')
        ? widget.initialPath
        : '/${widget.initialPath}';
    return '$_baseMarketplaceUrl$cleanPath';
  }

  @override
  void initState() {
    super.initState();
    _activeVoucherCode = widget.initialVoucherCode;
    _activeVoucherName = widget.initialVoucherName;
    _activeStoreName = widget.initialStoreName;
    _bootstrapMarketplace();
  }

  Future<void> _bootstrapMarketplace() async {
    final String? token = ApiConfig.userToken;

    if (token != null && token.trim().isNotEmpty) {
      try {
        final String meUrl = '${ApiConfig.baseUrl}/users/me';
        final res = await http.get(
          Uri.parse(meUrl),
          headers: ApiConfig.headers,
        );
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map) {
            final data = decoded['data'] ?? decoded;
            if (data is Map) {
              _cachedUser = Map<String, dynamic>.from(data);
            }
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (_isMobileWebViewSupported) {
      _initMobileWebView();
    }

    setState(() {
      _isInitializing = false;
    });
  }

  void _initMobileWebView() {
    final String? token = ApiConfig.userToken;
    _isPageLoading = true;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(surfaceBg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress / 100.0;
            });
          },
          onPageStarted: (String url) async {
            if (!mounted) return;
            setState(() {
              _isPageLoading = true;
              _hasError = false;
            });
            await _injectAuthSession(url);
          },
          onPageFinished: (String url) async {
            await _injectAuthSession(url, reloadIfFirstTime: true);
            final title = await _controller?.getTitle();
            if (!mounted) return;
            setState(() {
              _isPageLoading = false;
              if (title != null && title.trim().isNotEmpty) {
                _currentTitle = title.trim();
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _isPageLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            if (uri.scheme != 'http' && uri.scheme != 'https') {
              await _launchExternalUri(uri);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(_targetUrl),
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

    _controller = controller;
  }

  Future<void> _injectAuthSession(
    String url, {
    bool reloadIfFirstTime = false,
  }) async {
    final controller = _controller;
    if (controller == null || !url.startsWith(_baseMarketplaceUrl)) return;

    final String? token = ApiConfig.userToken;
    if (token == null || token.trim().isEmpty) return;

    final String safeToken = jsonEncode(token);
    final String safeUserJson =
        _cachedUser != null ? jsonEncode(jsonEncode(_cachedUser)) : 'null';
    final String safeVoucher =
        (_activeVoucherCode != null && _activeVoucherCode!.isNotEmpty)
            ? jsonEncode(_activeVoucherCode)
            : 'null';

    final String jsScript = '''
      (function() {
        try {
          var t = $safeToken;
          var u = $safeUserJson;
          var v = $safeVoucher;
          var changed = false;

          if (localStorage.getItem('ecocash.token') !== t) {
            localStorage.setItem('ecocash.token', t);
            changed = true;
          }
          if (u !== null && localStorage.getItem('ecocash.user') !== u) {
            localStorage.setItem('ecocash.user', u);
            changed = true;
          }
          if (v !== null) {
            localStorage.setItem('ecocash.selectedVoucher', v);
          }

          document.cookie = "ecocash.token=" + encodeURIComponent(t) + "; path=/; domain=.ecocash.id; SameSite=Lax; Secure";
          return changed;
        } catch (e) {
          return false;
        }
      })();
    ''';

    try {
      await controller.runJavaScript(jsScript);
      if (reloadIfFirstTime && !_sessionInjected) {
        _sessionInjected = true;
        await controller.reload();
      }
    } catch (_) {}
  }

  Future<void> _openVoucherSelector() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VoucherPage(isSelecting: true),
      ),
    );

    if (result is Map && result['code'] != null) {
      final code = result['code'].toString();
      final name = result['name']?.toString();
      final storeName = result['storeName']?.toString();

      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;

      setState(() {
        _activeVoucherCode = code;
        _activeVoucherName = name;
        _activeStoreName = storeName;
      });

      final currentUrl = await _controller?.currentUrl();
      if (currentUrl != null) {
        await _injectAuthSession(currentUrl);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kode $code disalin! Tempel di kolom promo saat checkout.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: textDark,
        ),
      );
    }
  }

  Future<void> _copyActiveVoucher() async {
    if (_activeVoucherCode == null || _activeVoucherCode!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _activeVoucherCode!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode $_activeVoucherCode berhasil disalin!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: textDark,
      ),
    );
  }

  Future<void> _launchExternalUri(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _handleBackNavigation() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: surfaceBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: brandYellow,
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back, color: textDark),
            onPressed: _handleBackNavigation,
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 11, color: ecoGreen),
                  SizedBox(width: 4),
                  Text(
                    'marketplace.ecocash.id',
                    style: TextStyle(
                      color: Color(0xFF3F3F46),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Pilih Voucher Promo',
              icon: const Icon(Icons.local_offer_outlined, color: textDark),
              onPressed: _openVoucherSelector,
            ),
            if (_controller != null)
              IconButton(
                tooltip: 'Muat Ulang',
                icon: const Icon(Icons.refresh_rounded, color: textDark),
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isPageLoading = true;
                  });
                  _controller?.reload();
                },
              ),
            IconButton(
              tooltip: 'Tutup EcoMart',
              icon: const Icon(Icons.close_rounded, color: textDark),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: (_isInitializing || _isPageLoading)
                ? LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    backgroundColor: brandYellow,
                    valueColor: const AlwaysStoppedAnimation<Color>(textDark),
                    minHeight: 3,
                  )
                : const SizedBox(height: 3),
          ),
        ),
        body: Column(
          children: [
            if (_activeVoucherCode != null && _activeVoucherCode!.isNotEmpty)
              _buildActiveVoucherBanner(),
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator(color: textDark))
                  : !_isMobileWebViewSupported
                      ? _buildWebOrDesktopIframe()
                      : _hasError
                          ? _buildErrorView()
                          : WebViewWidget(controller: _controller!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVoucherBanner() {
    final String subtitleText =
        (_activeStoreName != null && _activeStoreName!.isNotEmpty)
            ? 'Toko: $_activeStoreName • Tempel kode saat checkout'
            : (_activeVoucherName != null && _activeVoucherName!.isNotEmpty
                ? '$_activeVoucherName • Tempel kode saat checkout'
                : 'Kode sudah disalin, tempel saat checkout');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFECFDF5),
        border: Border(bottom: BorderSide(color: Color(0xFFA7F3D0))),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_rounded, size: 18, color: ecoGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voucher Aktif: $_activeVoucherCode',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46),
                  ),
                ),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: ecoGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _copyActiveVoucher,
            style: TextButton.styleFrom(
              foregroundColor: textDark,
              backgroundColor: brandYellow,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.content_copy_rounded, size: 13),
            label: const Text(
              'Salin',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() {
              _activeVoucherCode = null;
              _activeVoucherName = null;
              _activeStoreName = null;
            }),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 15, color: Color(0xFF065F46)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebOrDesktopIframe() {
    final controller = WebViewController()..loadRequest(Uri.parse(_targetUrl));
    return WebViewWidget(controller: controller);
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: brandYellow.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 46, color: textDark),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat EcoMart',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Periksa koneksi internet Anda lalu coba muat ulang halaman marketplace.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isPageLoading = true;
                });
                _controller?.loadRequest(Uri.parse(_targetUrl));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: textDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
