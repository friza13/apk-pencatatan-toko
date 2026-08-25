import 'package:flutter/material.dart';

/// Beranda — placeholder P0. Real dashboard (KPI, quick actions, insight)
/// diimplementasikan pada fase Reports/Dashboard sesuai DESAIN.md §9.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: const Center(child: Text('Dashboard NotaKit akan hadir di sini.')),
    );
  }
}
