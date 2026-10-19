/// Prekid GPS signala (rupa između dve uzastopne važeće tačke) i kako je
/// obračunat. Služi da vozač i putnik vide šta je naplaćeno za vreme bez signala.
class GapInfo {
  /// Vožnja je nastavljena posle zaustavljanja servisa (nije bilo merenja).
  static const String kindServiceRestart = 'service_restart';

  /// Brzina preko rupe je bila ispod praga: rupa je naplaćena kao čekanje.
  static const String kindWaiting = 'waiting';

  /// Brzina preko rupe je bila iznad praga: dodata je vazdušna linija.
  static const String kindDistance = 'distance';

  /// Skok nemoguće brzine posle duge rupe: ništa nije dodato.
  static const String kindSkipped = 'skipped';

  final DateTime startedAt; // UTC, poslednja važeća tačka pre rupe
  final int durationMs;
  final String kind;
  final int addedDistanceMeters;
  final int addedWaitingMs;

  const GapInfo({
    required this.startedAt,
    required this.durationMs,
    required this.kind,
    this.addedDistanceMeters = 0,
    this.addedWaitingMs = 0,
  });
}
