import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Menu Lainnya (DESAIN §8) — secondary navigation. Phase 2/3 features are
/// intentionally absent (amendment #16).
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        children: [
          const _SectionHeader('Kontak'),
          _MenuTile(
            icon: Icons.people_outline,
            label: 'Pelanggan',
            onTap: () => context.push('/more/customers'),
          ),
          _MenuTile(
            icon: Icons.local_shipping_outlined,
            label: 'Supplier',
            onTap: () => context.push('/more/suppliers'),
          ),
          _MenuTile(
            icon: Icons.badge_outlined,
            label: 'Salesman',
            onTap: () => context.push('/more/salesmen'),
          ),
          const _SectionHeader('Data & Referensi'),
          _MenuTile(
            icon: Icons.category_outlined,
            label: 'Kategori & Satuan',
            onTap: () => context.push('/more/references'),
          ),
          _MenuTile(
            icon: Icons.inventory_outlined,
            label: 'Stok (stok awal & penyesuaian)',
            onTap: () => _soon(context),
          ),
          const _SectionHeader('Toko'),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Pengaturan',
            onTap: () => _soon(context),
          ),
        ],
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur ini menyusul di fase berikutnya.')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}
