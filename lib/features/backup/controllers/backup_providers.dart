import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/providers.dart';
import '../data/backup_service.dart';

final FutureProvider<BackupService> backupServiceProvider =
    FutureProvider<BackupService>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      return BackupService(db);
    });
