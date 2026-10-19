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
  final int totalPrice;
  final String status; // completed | interrupted | cancelled

  /// Fiksna relacija (cena je fiksna); null = taksimetar po tarifi.
  final String? fixedRouteName;

  /// Ukupno pauzirano vreme (sekunde).
  final int pausedSeconds;

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
    required this.totalPrice,
    required this.status,
    this.fixedRouteName,
    this.pausedSeconds = 0,
  });

  bool get isInterrupted => status == 'interrupted';

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
