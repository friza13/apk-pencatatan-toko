import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';

/// Pengaturan profil toko (DESAIN §20, PRD §Q).
class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  ConsumerState<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _addressC = TextEditingController();
  final _footerNoteC = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    _footerNoteC.dispose();
    super.dispose();
  }

  void _initFromBusiness(Business business) {
    if (_initialized) return;
    _initialized = true;
    _nameC.text = business.name;
    _phoneC.text = business.phone ?? '';
    _addressC.text = business.address ?? '';
    _footerNoteC.text = business.footerNote ?? '';
  }

  Future<void> _save(Business business) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      await (db.update(
        db.businesses,
      )..where((t) => t.id.equals(business.id))).write(
        BusinessesCompanion(
          name: Value(_nameC.text.trim()),
          phone: Value(
            _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),
          ),
          address: Value(
            _addressC.text.trim().isEmpty ? null : _addressC.text.trim(),
          ),
          footerNote: Value(
            _footerNoteC.text.trim().isEmpty ? null : _footerNoteC.text.trim(),
          ),
        ),
      );

      ref.invalidate(currentBusinessProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan toko disimpan.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(currentBusinessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Toko')),
      body: businessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (business) {
          _initFromBusiness(business);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Informasi Toko',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameC,
                  decoration: const InputDecoration(
                    labelText: 'Nama Toko *',
                    hintText: 'Contoh: Toko Berkah',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama toko wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneC,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon / WhatsApp',
                    hintText: 'Contoh: 08123456789',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressC,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Toko',
                    hintText: 'Contoh: Jl. Sudirman No. 10',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Struk & Nota',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _footerNoteC,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Kaki Struk',
                    hintText: 'Contoh: Terima kasih atas kunjungan Anda!',
                    helperText: 'Ditampilkan di bagian bawah struk belanja.',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _save(business),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(_saving ? 'Menyimpan...' : 'Simpan Pengaturan'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
