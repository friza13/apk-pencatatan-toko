import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';

void main() {
  test('accounts insert+select smoke', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final ownerId =
        await db.into(db.owners).insert(OwnersCompanion.insert(name: 'O'));
    final bid = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'T'),
        );
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(businessId: bid, name: 'Kas'),
        );
    final rows = await db.select(db.accounts).get();
    // ignore: avoid_print
    print('rows=${rows.length} name=${rows.first.name} bal=${rows.first.currentBalanceMinor}');
    await db.close();
  });
}
