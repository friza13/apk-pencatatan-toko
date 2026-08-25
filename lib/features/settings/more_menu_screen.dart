import 'package:flutter/material.dart';

/// Menu Lainnya (drawer/secondary menu, DESAIN.md §8) — placeholder P0.
/// Real menu items muncul per fase; fitur Phase 2/3 tidak ditampilkan di MVP
/// (amendment #16).
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: const Center(child: Text('Menu sekunder akan hadir di sini.')),
    );
  }
}
