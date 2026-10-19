/// Prikaz iznosa u drugoj valuti, isključivo celobrojnom matematikom.
/// Kurs unosi korisnik; čuva se kao celi broj hiljaditih delova
/// (117.2 dinara za 1 EUR = 117200). Aplikacija nema ugrađen kurs.
class CurrencyConverter {
  /// "117.2" ili "117,20" → 117200. Najviše 3 decimale; null ako nije
  /// ispravan pozitivan broj.
  static int? parseRateMilli(String input) {
    final text = input.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d{1,6})(?:\.(\d{1,3}))?$').firstMatch(text);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(3, '0');
    final milli = whole * 1000 + int.parse(fraction);
    return milli > 0 ? milli : null;
  }

  /// 117200 → "117.2"
  static String formatRate(int rateMilli) {
    final whole = rateMilli ~/ 1000;
    final fraction = (rateMilli % 1000).toString().padLeft(3, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
  }

  /// Dinari → EUR sa dve decimale, zaokruženo na cent (.5 naviše).
  static String formatForeign(int dinars, int rateMilli) {
    if (rateMilli <= 0) throw ArgumentError('Kurs mora biti veći od 0.');
    final cents = (dinars * 100000 + rateMilli ~/ 2) ~/ rateMilli;
    final euros = cents ~/ 100;
    final rest = (cents % 100).toString().padLeft(2, '0');
    return '$euros.$rest';
  }
}
