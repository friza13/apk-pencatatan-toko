import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';

/// Pelanggan list (DESAIN §14): contact-manager feel with quick actions.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();
  List<Customer> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload([String q = '']) async {
    setState(() => _loading = true);
    final repoFuture = ref.read(referenceRepositoryProvider.future);
    await repoFuture; // ensure defaults seeded
    final business = await ref.read(currentBusinessProvider.future);
    final db = await ref.read(appDatabaseProvider.future);
    final rows = await (db.select(db.customers)
          ..where((t) => t.businessId.equals(business.id))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    Iterable<Customer> result = rows;
    final query = q.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((c) =>
          c.name.toLowerCase().contains(query) ||
          (c.phone ?? '').contains(query));
    }
    if (!mounted) return;
    setState(() {
      _items = result.toList();
      _loading = false;
    });
  }

  Future<void> _openForm([Customer? existing]) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: nameC,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneC,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telepon/WhatsApp'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(existing == null ? 'Simpan' : 'Update'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final business = await ref.read(currentBusinessProvider.future);
    final db = await ref.read(appDatabaseProvider.future);
    if (existing == null) {
      await db.into(db.customers).insert(CustomersCompanion.insert(
            businessId: business.id,
            name: nameC.text.trim(),
            phone: Value(phoneC.text.trim().isEmpty ? null : phoneC.text.trim()),
          ));
    } else {
      await (db.update(db.customers)..where((t) => t.id.equals(existing.id)))
          .write(CustomersCompanion(
        name: Value(nameC.text.trim()),
        phone: Value(phoneC.text.trim().isEmpty ? null : phoneC.text.trim()),
      ));
    }
    await _reload(_search.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-add-customer',
        onPressed: _openForm,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Pelanggan'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Cari nama atau telepon...',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: _reload,
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          const Text('Belum ada pelanggan'),
                          const SizedBox(height: 8),
                          const Text(
                              'Tambahkan pelanggan untuk mulai mencatat piutang.'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Theme.of(context).dividerColor),
                      itemBuilder: (context, i) {
                        final c = _items[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(c.name.isEmpty ? '?' : c.name[0]),
                          ),
                          title: Text(c.name),
                          subtitle: Text(c.phone ?? '-'),
                          onTap: () => _openForm(c),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
