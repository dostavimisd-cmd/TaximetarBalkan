import 'models/fare_result.dart';
import 'models/tariff.dart';

class FareCalculator {
  /// Jedino mesto u aplikaciji za finansijsko celobrojno zaokruživanje (.5 naviše)
  /// Koristi matematički pristup: (brojilac + (imenilac / 2)) / imenilac
  static int _roundHalfUp(int numerator, int denominator) {
    return (numerator + (denominator ~/ 2)) ~/ denominator;
  }

  /// Obračunava cenu vožnje isključivo celobrojnom matematikom.
  static FareResult calculate({
    required Tariff tariff,
    required int distanceMeters,
    required int waitingSeconds,
    double calibrationMultiplier = 1.0,
  }) {
    // Provera ulaznih parametara
    if (distanceMeters < 0) throw ArgumentError('Distanca ne sme biti negativna.');
    if (waitingSeconds < 0) throw ArgumentError('Vreme čekanja ne sme biti negativno.');
    if (calibrationMultiplier <= 0) throw ArgumentError('Kalibracija mora biti veća od 0.');

    // 1. Kalibrisani metri se zaokružuju na ceo metar
    final int calibratedMeters = (distanceMeters * calibrationMultiplier).round();

    // 2. Cena po kilometru (1000 metara)
    // Formula: (metri * cena) / 1000
    final int kmPrice = _roundHalfUp(calibratedMeters * tariff.pricePerKm, 1000);

    // 3. Cena za čekanje: cena po minutu je u para (1/100 dinara)
    // Formula: (sekunde * para po minutu) / (60 * 100)
    final int waitingPrice =
        _roundHalfUp(waitingSeconds * tariff.waitingParaPerMin, 6000);

    // 4. Sabiranje
    final int startPrice = tariff.startPrice;
    int baseTotal = startPrice + kmPrice + waitingPrice;
    int total = baseTotal;
    int adjustment = 0;
    bool minApplied = false;

    // 5. Provera minimalne cene
    if (total < tariff.minPrice) {
      adjustment = tariff.minPrice - total;
      total = tariff.minPrice;
      minApplied = true;
    }

    return FareResult(
      startPrice: startPrice,
      kmPrice: kmPrice,
      waitingPrice: waitingPrice,
      minPriceAdjustment: adjustment,
      totalPrice: total,
      isMinPriceApplied: minApplied,
    );
  }
}