import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:notakit/core/app/app_metadata.dart';
import 'package:notakit/database/app_database.dart';

void main() {
  test('loads runtime app version and database schema version', () async {
    PackageInfo.setMockInitialValues(
      appName: 'NotaKit',
      packageName: 'com.example.notakit',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final metadata = await AppMetadata.load(db);

    expect(metadata.appVersion, '1.2.3+45');
    expect(metadata.schemaVersion, db.schemaVersion);
  });
}
