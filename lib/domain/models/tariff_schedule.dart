/// Kada tarifa važi automatski: dani u nedelji i lokalno vreme od–do.
/// Vreme je "zidni sat" vozača (lokalno), jer tako glase tarifni pravilnici.
class TariffSchedule {
  /// Bit 0 = ponedeljak … bit 6 = nedelja (kao DateTime.weekday - 1).
  final int days;

  /// Minuti od ponoći, 0–1439. Ako je [endMinute] < [startMinute], period
  /// prelazi ponoć i pripada danu u kome počinje (pet 22:00–06:00 važi i u
  /// subotu do 06:00). Ako su jednaki, važi ceo dan.
  final int startMinute;
  final int endMinute;

  const TariffSchedule({
    required this.days,
    required this.startMinute,
    required this.endMinute,
  });

  static const int allDays = 0x7f;

  bool get isEmpty => days == 0;

  static bool _hasDay(int days, int weekday) => days & (1 << (weekday - 1)) != 0;

  bool includesDay(int weekday) => _hasDay(days, weekday);

  /// Da li raspored važi u datom lokalnom trenutku.
  bool matches(DateTime local) {
    if (isEmpty) return false;
    final minute = local.hour * 60 + local.minute;
    if (startMinute == endMinute) return _hasDay(days, local.weekday);
    if (startMinute < endMinute) {
      return _hasDay(days, local.weekday) &&
          minute >= startMinute &&
          minute < endMinute;
    }
    // preko ponoći
    final yesterday = local.weekday == DateTime.monday ? DateTime.sunday : local.weekday - 1;
    return (_hasDay(days, local.weekday) && minute >= startMinute) ||
        (_hasDay(days, yesterday) && minute < endMinute);
  }

  String? validate() {
    if (days < 0 || days > allDays) return 'Neispravni dani rasporeda.';
    if (startMinute < 0 || startMinute > 1439 || endMinute < 0 || endMinute > 1439) {
      return 'Vreme rasporeda mora biti od 00:00 do 23:59.';
    }
    return null;
  }

  static String formatMinute(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  static const List<String> dayLetters = ['P', 'U', 'S', 'Č', 'P', 'S', 'N'];

  /// npr. "P U S Č P · 22:00–06:00" ili "svaki dan · ceo dan"
  String describe() {
    if (isEmpty) return 'bez rasporeda';
    final dayText = days == allDays
        ? 'svaki dan'
        : [for (var i = 0; i < 7; i++) if (days & (1 << i) != 0) dayLetters[i]].join(' ');
    final time = startMinute == endMinute
        ? 'ceo dan'
        : '${formatMinute(startMinute)}–${formatMinute(endMinute)}';
    return '$dayText · $time';
  }
}
