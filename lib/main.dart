import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:ecocash_indonesia/landingpage.dart';
import 'package:ecocash_indonesia/Auth/login.dart';
import 'package:ecocash_indonesia/Auth/email_verification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // ============================================================
  // RESOLVE URL
  // ============================================================

  Uri _resolveUri(String? routeName) {
    final Uri routeUri = Uri.parse(routeName ?? '/');

    // Jika Flutter sudah mendapatkan route yang jelas,
    // gunakan route tersebut.
    if (routeUri.path != '/' ||
        routeUri.queryParameters.isNotEmpty) {
      return routeUri;
    }

    final Uri browserUri = Uri.base;

    /*
     * Mendukung URL HASH:
     *
     * http://localhost:5000/#/verify-email?token=ABC
     *
     * Ini paling aman untuk Flutter Web local development.
     */
    final String fragment = browserUri.fragment.trim();

    if (fragment.startsWith('/')) {
      return Uri.parse(fragment);
    }

    /*
     * Mendukung URL CLEAN:
     *
     * http://localhost:5000/verify-email?token=ABC
     */
    if (browserUri.path == '/verify-email' ||
        browserUri.path == '/login') {
      return browserUri;
    }

    return routeUri;
  }

  // ============================================================
  // ROUTES
  // ============================================================

  Route<dynamic> _generateRoute(RouteSettings settings) {
    final Uri uri = _resolveUri(settings.name);

    debugPrint('');
    debugPrint('======================================');
    debugPrint('ECOCASH ROUTER');
    debugPrint('SETTINGS : ${settings.name}');
    debugPrint('URI      : $uri');
    debugPrint('PATH     : ${uri.path}');
    debugPrint(
      'HAS TOKEN: '
      '${uri.queryParameters['token']?.isNotEmpty == true}',
    );
    debugPrint('======================================');
    debugPrint('');

    // ==========================================================
    // EMAIL VERIFICATION
    // ==========================================================

    if (uri.path == '/verify-email') {
      final String token =
          uri.queryParameters['token']?.trim() ?? '';

      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          return EmailVerificationPage(
            token: token,
          );
        },
      );
    }

    // ==========================================================
    // LOGIN
    // ==========================================================

    if (uri.path == '/login') {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          return const LoginPage();
        },
      );
    }

    // ==========================================================
    // DEFAULT / LANDING PAGE
    // ==========================================================

    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        return const EcoCashKidsApp();
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoCash Indonesia',

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),

      onGenerateRoute: _generateRoute,
    );
  }
}