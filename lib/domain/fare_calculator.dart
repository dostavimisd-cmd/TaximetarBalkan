import 'models/fare_result.dart';
import 'models/tariff.dart';

class FareCalculator {
  /// Obračunava cenu vožnje na osnovu tarife, distance, čekanja i kalibracije.
  /// Nema nikakvih zavisnosti od Fluttera.
  static FareResult calculate({
    required Tariff tariff,
    required int distanceMeters,
    required int waitingSeconds,
    double calibrationMultiplier = 1.0,
  }) {
    // 1. Primena kalibracije na distancu
    final double calibratedDistance = distanceMeters * calibrationMultiplier;

    // 2. Obračun cene za kilometre (i zaokruživanje)
    final double kmFareRaw = (calibratedDistance / 1000) * tariff.pricePerKm;
    final int kmPrice = kmFareRaw.round();

    // 3. Obračun cene za čekanje (i zaokruživanje)
    final double waitingFareRaw = (waitingSeconds / 60) * tariff.waitingPricePerMin;
    final int waitingPrice = waitingFareRaw.round();

    // 4. Sabiranje
    int total = tariff.startPrice + kmPrice + waitingPrice;
    bool minApplied = false;

    // 5. Provera minimalne cene
    if (total < tariff.minPrice) {
      total = tariff.minPrice;
      minApplied = true;
    }

    return FareResult(
      startPrice: tariff.startPrice,
      kmPrice: kmPrice,
      waitingPrice: waitingPrice,
      totalPrice: total,
      isMinPriceApplied: minApplied,
    );
  }
}