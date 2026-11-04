import 'extra_charge.dart';

/// Završena ili prekinuta vožnja, onako kako je upisana u bazu.
class RideRecord {
  final int id;
  final DateTime startTime; // UTC
  final DateTime? endTime; // UTC; null ako nikad nije zatvorena
  final int distanceMeters;
  final int waitingSeconds;
  final int startPrice;
  final int kmPrice;
  final int waitingPrice;
  final int minPriceAdjustment;

  /// Zbir doplata (uračunat u [totalPrice]).
  final int extrasTotal;
  final int totalPrice;
  final String status; // completed | interrupted | cancelled

  /// Fiksna relacija (cena je fiksna); null = taksimetar po tarifi.
  final String? fixedRouteName;

  /// Ukupno pauzirano vreme (sekunde).
  final int pausedSeconds;

  /// Pojedinačne doplate; puni se samo za jednu vožnju (`getById`).
  final List<ExtraCharge> extras;

  const RideRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.waitingSeconds,
    required this.startPrice,
    required this.kmPrice,
    required this.waitingPrice,
    required this.minPriceAdjustment,
    this.extrasTotal = 0,
    required this.totalPrice,
    required this.status,
    this.fixedRouteName,
    this.pausedSeconds = 0,
    this.extras = const [],
  });

  /// Doplate za prikaz: pojedinačne ako su učitane, inače jedan red sa zbirom.
  List<ExtraCharge> extrasOr(String label) => extras.isNotEmpty
      ? extras
      : [if (extrasTotal > 0) ExtraCharge(name: label, amount: extrasTotal)];

  bool get isInterrupted => status == 'interrupted';

  /// Cena bez doplata (za fiksnu relaciju to je fiksna cena).
  int get priceWithoutExtras => totalPrice - extrasTotal;

  Duration? get duration => endTime?.difference(startTime);

  /// Trajanje bez pauze (vreme u kome je taksimetar stvarno radio).
  Duration? get activeDuration {
    final d = duration;
    if (d == null) return null;
    final a = d - Duration(seconds: pausedSeconds);
    return a.isNegative ? Duration.zero : a;
  }

  /// Prosečna brzina (km/h) u toku rada; null ako je vreme kratko (< 30 s).
  double? get averageSpeedKmh {
    final a = activeDuration;
    if (a == null || a.inSeconds < 30) return null;
    return distanceMeters / 1000 / (a.inSeconds / 3600);
  }
}
