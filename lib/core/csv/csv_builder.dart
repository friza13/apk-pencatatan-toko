/// Minimal RFC4180 CSV builder (D-015): UTF-8, comma delimiter, quote
/// escaping for quotes/newlines/commas. Indonesian spreadsheets open this
/// fine when the consumer uses the import wizard; numbers use dot decimals.
class CsvBuilder {
  final List<List<String>> _rows = [];

  void row(List<Object?> cells) =>
      _rows.add(cells.map((c) => c?.toString() ?? '').toList());

  String build({bool includeBom = true}) {
    final body = _rows.map(_encodeRow).join('\r\n');
    return includeBom ? '\uFEFF$body' : body;
  }

  String _encodeRow(List<String> cells) => cells.map(escapeCell).join(',');

  static String escapeCell(String raw) {
    final needsQuotes =
        raw.contains(',') || raw.contains('"') || raw.contains('\n');
    final escaped = raw.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
