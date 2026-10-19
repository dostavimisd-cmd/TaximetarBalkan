/// Koliko često se osvežava cena na ekranu tokom vožnje (kao "Refresh time"
/// kod drugih taksimetara). Obračun se ne menja — samo prikaz kasni najviše
/// [intervalMs]. Promena faze (start, kraj) prikazuje se odmah.
class PriceThrottle {
  static const List<int> allowedSeconds = [1, 4, 6, 10];

  int? _shown;
  int _shownAtMs = 0;

  int show(int latest, int nowMs, int intervalMs, {bool force = false}) {
    final shown = _shown;
    if (force || shown == null || latest == shown || nowMs - _shownAtMs >= intervalMs) {
      if (shown != latest) _shownAtMs = nowMs;
      _shown = latest;
    }
    return _shown!;
  }
}
