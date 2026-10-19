/// Kalibracija distance: korisnik unosi procenat korekcije (npr. +2,5 ili -1),
/// a čuva se kao ceo broj promila (1000 = bez korekcije).
class Calibration {
  static const int neutralPermille = 1000;

  /// Tehničke granice (±50%), da pogrešan unos ne obori obračun.
  static const int minPermille = 500;
  static const int maxPermille = 1500;

  /// "+2.5" / "-1,5" / "0" → promili (1025 / 985 / 1000). Najviše 1 decimala.
  /// null ako unos nije ispravan ili je van granica.
  static int? parsePercent(String input) {
    final text = input.trim().replaceAll(',', '.');
    final match = RegExp(r'^([+-])?(\d{1,3})(?:\.(\d))?$').firstMatch(text);
    if (match == null) return null;
    final tenths = int.parse(match.group(2)!) * 10 + int.parse(match.group(3) ?? '0');
    final delta = match.group(1) == '-' ? -tenths : tenths;
    final permille = neutralPermille + delta;
    return isValid(permille) ? permille : null;
  }

  /// 1025 → "2.5", 985 → "-1.5", 1000 → "0"
  static String formatPercent(int permille) {
    final delta = permille - neutralPermille;
    final sign = delta < 0 ? '-' : '';
    final tenths = delta.abs();
    final whole = tenths ~/ 10;
    final frac = tenths % 10;
    return frac == 0 ? '$sign$whole' : '$sign$whole.$frac';
  }

  static bool isValid(int permille) => permille >= minPermille && permille <= maxPermille;
}
