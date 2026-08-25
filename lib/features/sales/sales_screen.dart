import 'package:flutter/material.dart';

/// Daftar nota — placeholder P0. Real implementation pada fase P6.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan')),
      body: const Center(child: Text('Daftar nota akan hadir di sini.')),
    );
  }
}
