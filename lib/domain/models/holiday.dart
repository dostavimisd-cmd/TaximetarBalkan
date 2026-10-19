/// Praznik koji korisnik unosi: tog dana (ceo dan, lokalno) važi izabrana
/// tarifa. Aplikacija nema ugrađene praznike (Pravilo 3).
class Holiday {
  final int id; // 0 = nov
  final String name;
  final int month;
  final int day;

  /// null = ponavlja se svake godine.
  final int? year;
  final int tariffId;

  const Holiday({
    this.id = 0,
    required this.name,
    required this.month,
    required this.day,
    this.year,
    required this.tariffId,
  });

  bool get recurring => year == null;

  bool matches(DateTime local) =>
      local.month == month && local.day == day && (year == null || local.year == year);

  String? validate() {
    if (name.trim().isEmpty) return 'Naziv praznika je obavezan.';
    if (month < 1 || month > 12) return 'Neispravan mesec.';
    // 2000 je prestupna, pa je 29.2. dozvoljen za praznike koji se ponavljaju.
    final y = year ?? 2000;
    final check = DateTime(y, month, day);
    if (day < 1 || check.month != month || check.day != day) return 'Neispravan datum.';
    if (tariffId <= 0) return 'Izaberi tarifu za praznik.';
    return null;
  }

  /// "YYYY-MM-DD" ili "MM-DD" (svake godine) — format kolone date_string.
  String get dateString {
    String two(int v) => v.toString().padLeft(2, '0');
    return year == null ? '${two(month)}-${two(day)}' : '$year-${two(month)}-${two(day)}';
  }

  /// Obrnuto od [dateString]; null ako zapis nije ispravan.
  static ({int? year, int month, int day})? parseDateString(String s) {
    final m = RegExp(r'^(?:(\d{4})-)?(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return null;
    return (
      year: m.group(1) == null ? null : int.parse(m.group(1)!),
      month: int.parse(m.group(2)!),
      day: int.parse(m.group(3)!),
    );
  }

  String describe({bool english = false}) {
    String two(int v) => v.toString().padLeft(2, '0');
    return year == null ? '${two(day)}.${two(month)}. (${english ? 'every year' : 'svake godine'})' : '${two(day)}.${two(month)}.$year.';
  }
}
