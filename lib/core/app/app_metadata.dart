import 'package:package_info_plus/package_info_plus.dart';

import '../../database/app_database.dart';

class AppMetadata {
  const AppMetadata({required this.appVersion, required this.schemaVersion});

  final String appVersion;
  final int schemaVersion;

  static Future<AppMetadata> load(AppDatabase db) async {
    final info = await PackageInfo.fromPlatform();
    return AppMetadata(
      appVersion: '${info.version}+${info.buildNumber}',
      schemaVersion: db.schemaVersion,
    );
  }
}
