import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kategori'),
              Tab(text: 'Satuan'),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            heroTag: 'fab-add-reference',
            onPressed: () => _add(context),
            child: const Icon(Icons.add),
          ),
        ),
        body: TabBarView(
          children: [_categoryList(categories), _unitList(units)],
        ),
      ),
    );
  }

  Widget _categoryList(List<Category> categories) {
    if (categories.isEmpty) {
      return const Center(child: Text('Belum ada kategori.'));
    }
    return ListView(
      children: [
        for (final category in categories)
          ListTile(
            title: Text(category.name),
            subtitle: category.isActive ? null : const Text('Nonaktif'),
            trailing: _actions(
              onEdit: () => _editCategory(category),
              onToggle: () => _toggleCategory(category),
              active: category.isActive,
            ),
          ),
      ],
    );
  }

  Widget _unitList(List<Unit> units) {
    if (units.isEmpty) {
      return const Center(child: Text('Belum ada satuan.'));
    }
    return ListView(
      children: [
        for (final unit in units)
          ListTile(
            title: Text('${unit.code} - ${unit.name}'),
            subtitle: unit.isActive ? null : const Text('Nonaktif'),
            trailing: _actions(
              onEdit: () => _editUnit(unit),
              onToggle: () => _toggleUnit(unit),
              active: unit.isActive,
            ),
          ),
      ],
    );
  }

  Widget _actions({
    required VoidCallback onEdit,
    required VoidCallback onToggle,
    required bool active,
  }) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else {
          onToggle();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
          value: 'toggle',
          child: Text(active ? 'Nonaktifkan' : 'Aktifkan'),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final isCategory = DefaultTabController.of(context).index == 0;
    if (isCategory) {
      final name = await _categoryDialog(context);
      if (name == null) return;
      final business = await ref.read(currentBusinessProvider.future);
      final repository = await ref.read(referenceRepositoryProvider.future);
      await repository.addCategory(businessId: business.id, name: name);
    } else {
      final values = await _unitDialog(context);
      if (values == null) return;
      final business = await ref.read(currentBusinessProvider.future);
      final repository = await ref.read(referenceRepositoryProvider.future);
      await repository.addUnit(
        businessId: business.id,
        code: values.code,
        name: values.name,
      );
    }
    _refresh();
  }

  Future<void> _editCategory(Category category) async {
    final name = await _categoryDialog(context, initialName: category.name);
    if (name == null) return;
    final repository = await ref.read(referenceRepositoryProvider.future);
    await repository.renameCategory(category.id, name);
    _refresh();
  }

  Future<void> _editUnit(Unit unit) async {
    final values = await _unitDialog(
      context,
      initialCode: unit.code,
      initialName: unit.name,
    );
    if (values == null) return;
    final repository = await ref.read(referenceRepositoryProvider.future);
    await repository.updateUnit(
      id: unit.id,
      code: values.code,
      name: values.name,
      symbol: unit.symbol,
      decimalScale: unit.decimalScale,
    );
    _refresh();
  }

  Future<void> _toggleCategory(Category category) async {
    final repository = await ref.read(referenceRepositoryProvider.future);
    await repository.setCategoryActive(category.id, !category.isActive);
    _refresh();
  }

  Future<void> _toggleUnit(Unit unit) async {
    final repository = await ref.read(referenceRepositoryProvider.future);
    await repository.setUnitActive(unit.id, !unit.isActive);
    _refresh();
  }

  void _refresh() {
    ref
      ..invalidate(categoriesStreamProvider)
      ..invalidate(unitsStreamProvider);
  }

  Future<String?> _categoryDialog(
    BuildContext context, {
    String? initialName,
  }) async {
    var value = initialName ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName == null ? 'Tambah Kategori' : 'Edit Kategori'),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: initialName),
          onChanged: (text) => value = text,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final trimmed = value.trim();
    return saved == true && trimmed.isNotEmpty ? trimmed : null;
  }

  Future<_UnitFormValues?> _unitDialog(
    BuildContext context, {
    String? initialCode,
    String? initialName,
  }) async {
    var code = initialCode ?? '';
    var name = initialName ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialCode == null ? 'Tambah Satuan' : 'Edit Satuan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              controller: TextEditingController(text: initialCode),
              onChanged: (value) => code = value,
              decoration: const InputDecoration(
                labelText: 'Kode satuan (mis. kg)',
              ),
            ),
            TextField(
              controller: TextEditingController(text: initialName),
              onChanged: (value) => name = value,
              decoration: const InputDecoration(labelText: 'Nama satuan'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final trimmedCode = code.trim();
    final trimmedName = name.trim();
    return saved == true && trimmedCode.isNotEmpty && trimmedName.isNotEmpty
        ? _UnitFormValues(code: trimmedCode, name: trimmedName)
        : null;
  }
}

class _UnitFormValues {
  const _UnitFormValues({required this.code, required this.name});

  final String code;
  final String name;
}
