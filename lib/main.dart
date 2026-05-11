import 'package:ecocash_indonesia/home.dart';
import 'package:ecocash_indonesia/landingpage.dart';
import 'package:ecocash_indonesia/setor_sampah/konfirmasi.dart';
import 'package:ecocash_indonesia/setor_sampah/transaksi.dart';
import 'package:flutter/material.dart';
// import 'Auth/login.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoCash',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green, // Tema hijau untuk EcoCash
      ),
      home: const SplashLandingPage(),
    );
  }
}
