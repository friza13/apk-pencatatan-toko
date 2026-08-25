import 'package:flutter/material.dart';

/// Daftar produk — placeholder P0. Real implementation pada fase P4.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      body: const Center(child: Text('Daftar produk akan hadir di sini.')),
    );
  }
}
