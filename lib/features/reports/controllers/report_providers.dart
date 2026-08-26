import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/providers.dart';
import '../data/report_repository.dart';

final FutureProvider<ReportRepository> reportRepositoryProvider =
    FutureProvider<ReportRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ReportRepository(db);
});
