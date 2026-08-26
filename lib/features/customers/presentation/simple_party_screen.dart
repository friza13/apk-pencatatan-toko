import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';

/// Simple list+add screens for Supplier and Salesman.
class SimplePartyScreen extends ConsumerStatefulWidget {
  const SimplePartyScreen({super.key, required this.isSupplier});

  final bool isSupplier;

  @override
  ConsumerState<SimplePartyScreen> createState() => _SimplePartyScreenState();
}

class _SimplePartyScreenState extends ConsumerState<SimplePartyScreen> {
  List<Supplier> _suppliers = [];
  List<Salesman> _salesmen = [];
  bool _loading = true;

  String get _title => widget.isSupplier ? 'Supplier' : 'Salesman';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final db = await ref.read(appDatabaseProvider.future);
    final business = await ref.read(currentBusinessProvider.future);

    _suppliers = await (db.select(db.suppliers)
          ..where((t) => t.businessId.equals(business.id))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    _salesmen = await (db.select(db.salesmen)
          ..where((t) => t.businessId.equals(business.id))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tambah $_title'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Nama $_title *'),
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
    if (saved != true || c.text.trim().isEmpty) return;

    final db = await ref.read(appDatabaseProvider.future);
    final business = await ref.read(currentBusinessProvider.future);
    if (widget.isSupplier) {
      await db.into(db.suppliers).insert(SuppliersCompanion.insert(
            businessId: business.id,
            name: c.text.trim(),
          ));
    } else {
      await db.into(db.salesmen).insert(SalesmenCompanion.insert(
            businessId: business.id,
            code: 'SL-${DateTime.now().millisecondsSinceEpoch % 100000}',
            name: c.text.trim(),
          ));
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-party-${widget.isSupplier}',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.isSupplier
              ? (_suppliers.isEmpty
                  ? const Center(child: Text('Belum ada supplier.'))
                  : ListView(
                      children: [
                        for (final s in _suppliers) ListTile(title: Text(s.name)),
                      ],
                    ))
              : (_salesmen.isEmpty
                  ? const Center(child: Text('Belum ada salesman.'))
                  : ListView(
                      children: [
                        for (final s in _salesmen)
                          ListTile(title: Text(s.name), subtitle: Text(s.code)),
                      ],
                    )),
    );
  }
}
