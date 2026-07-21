import 'package:ecocash_indonesia/home.dart';
import 'package:ecocash_indonesia/landingpage.dart';
import 'package:ecocash_indonesia/setor_sampah/konfirmasi.dart';
import 'package:ecocash_indonesia/setor_sampah/transaksi.dart';
import 'package:ecocash_indonesia/ecomer/OrdersPage.dart';
import 'package:ecocash_indonesia/ecomer/orderdetail.dart';
import 'package:ecocash_indonesia/ecomer/cart.dart';
import 'package:flutter/material.dart';
import 'package:ecocash_indonesia/ipconfig.dart';
// import 'Auth/login.dart';

void main() {
  // Set your machine's local IP for physical Android device connection
  ApiConfig.customHost = "127.0.0.1";
  runApp(const MainApp());
}


class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoCash Indonesia',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green, // Tema hijau untuk EcoCash
      ),
      home: const EcoCashKidsApp(),
    );
  }
}
