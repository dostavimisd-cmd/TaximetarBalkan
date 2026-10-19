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
  });

  bool get isInterrupted => status == 'interrupted';

  Duration? get duration => endTime?.difference(startTime);
}
