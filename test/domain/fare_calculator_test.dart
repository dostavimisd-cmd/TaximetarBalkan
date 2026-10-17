import 'package:flutter_test/flutter_test.dart';

// ZAMENI 'ime_tvog_projekta' sa tačnim nazivom iz pubspec.yaml fajla
import 'package:taksimetar_balkan/domain/fare_calculator.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

void main() {
  group('FareCalculator Tests', () {
    const defaultTariff = Tariff(
      startPrice: 150,
      pricePerKm: 80,
      waitingPricePerMin: 10,
      minPrice: 200,
    );

    test('Vožnja bez čekanja (nema minimalne cene)', () {
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 2000, // 2 km = 160
        waitingSeconds: 0,
      );

      expect(result.startPrice, 150);
      expect(result.kmPrice, 160);
      expect(result.waitingPrice, 0);
      expect(result.totalPrice, 310);
      expect(result.isMinPriceApplied, false);
    });

    test('Vožnja sa čekanjem', () {
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 5000, // 5 km = 400
        waitingSeconds: 300, // 5 min = 50
      );

      expect(result.kmPrice, 400);
      expect(result.waitingPrice, 50);
      expect(result.totalPrice, 600); // 150 + 400 + 50
    });

    test('Primenjena minimalna cena', () {
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 100, // 0.1 km = 8
        waitingSeconds: 0,
      );

      // Start 150 + 8 = 158. Minimalna je 200.
      expect(result.kmPrice, 8);
      expect(result.totalPrice, 200);
      expect(result.isMinPriceApplied, true);
    });

    test('Koeficijent kalibracije menja obračun distance', () {
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 1000, // Originalno 1 km
        waitingSeconds: 0,
        calibrationMultiplier: 1.05, // 5% veći impuls (1.05 km = 84 din)
      );

      expect(result.kmPrice, 84); 
      expect(result.totalPrice, 234); // 150 + 84
    });

    test('Nula pređenih kilometara i minuta', () {
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 0,
        waitingSeconds: 0,
      );

      expect(result.totalPrice, 200); // Primeniće se min cena jer je 150 < 200
      expect(result.isMinPriceApplied, true);
    });

    test('Pravila zaokruživanja: > 0.5 se zaokružuje na gore', () {
      // 1250 metara = 1.25 km. 1.25 * 80 = 100
      // 35 sekundi = 0.5833 min. 0.5833 * 10 = 5.833 -> 6 dinara.
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 1250,
        waitingSeconds: 35, 
      );

      expect(result.kmPrice, 100);
      expect(result.waitingPrice, 6);
      expect(result.totalPrice, 256); // 150 + 100 + 6
    });
  });
}