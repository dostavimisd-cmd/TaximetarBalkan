import 'fare_calculator.dart';
import 'models/tariff.dart';

/// Približna cena za predloženu rutu (pre vožnje). Čekanje u saobraćaju se
/// ne zna unapred, pa se procena računa bez čekanja — stvarna cena je obično
/// malo veća. Fiksna relacija ima tačnu cenu.
class FareEstimate {
  static int forRoute({
    required Tariff tariff,
    required int distanceMeters,
    int calibrationPermille = 1000,
    int? fixedPrice,
  }) {
    if (fixedPrice != null) return fixedPrice;
    return FareCalculator.calculate(
      tariff: tariff,
      distanceMeters: distanceMeters < 0 ? 0 : distanceMeters,
      waitingSeconds: 0,
      calibrationPermille: calibrationPermille,
    ).totalPrice;
  }
}
