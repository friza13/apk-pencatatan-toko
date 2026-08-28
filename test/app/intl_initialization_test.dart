import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  test('id_ID locale date formatting works after initialization', () async {
    await initializeDateFormatting('id_ID');
    final dt = DateTime(2026, 8, 28, 14, 30);
    final formatted = DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(dt);
    expect(formatted, contains('28 Agu 2026 14:30'));
  });
}
