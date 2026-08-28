import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/controllers/products_providers.dart';

/// Kategori, satuan & tipe pelanggan management (combined screen).
class ReferencesScreen extends ConsumerStatefulWidget {
  const ReferencesScreen({super.key});

  @override
  ConsumerState<ReferencesScreen> createState() => _ReferencesScreenState();
}

class _ReferencesScreenState extends ConsumerState<ReferencesScreen> {
  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider).value ?? [];
    final units = ref.watch(unitsStreamProvider).value ?? [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategori & Satuan'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Kategori'),
            Tab(text: 'Satuan'),
          ]),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            heroTag: 'fab-add-reference',
            onPressed: () => _add(context),
            child: const Icon(Icons.add),
          ),
        ),
        body: TabBarView(children: [
          // Kategori
          categories.isEmpty
              ? const Center(child: Text('Belum ada kategori.'))
              : ListView(
                  children: [
                    for (final c in categories)
                      ListTile(title: Text(c.name)),
                  ],
                ),
          // Satuan
          units.isEmpty
              ? const Center(child: Text('Belum ada satuan.'))
              : ListView(
                  children: [
                    for (final u in units)
                      ListTile(
                        title: Text('${u.code} - ${u.name}'),
                      ),
                  ],
                ),
        ]),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final tabs = DefaultTabController.maybeOf(context);
    final isCategory = tabs?.index == 0;

    final c1 = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCategory ? 'Tambah Kategori' : 'Tambah Satuan'),
        content: TextField(
          controller: c1,
          autofocus: true,
          decoration: InputDecoration(
              labelText: isCategory ? 'Nama kategori' : 'Kode satuan (mis. kg)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (saved != true || c1.text.trim().isEmpty) return;

    final business = await ref.read(currentBusinessProvider.future);
    final refs = await ref.read(referenceRepositoryProvider.future);
    if (isCategory) {
      await refs.addCategory(businessId: business.id, name: c1.text.trim());
    } else {
      await refs.addUnit(
        businessId: business.id,
        code: c1.text.trim(),
        name: c1.text.trim(),
      );
    }
    ref
      ..invalidate(categoriesStreamProvider)
      ..invalidate(unitsStreamProvider);
  }
}
