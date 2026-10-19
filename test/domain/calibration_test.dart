import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/calibration.dart';
import 'package:taksimetar_balkan/domain/fare_calculator.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

void main() {
  group('Calibration unos', () {
    test('parsePercent: znak, zarez, jedna decimala', () {
      expect(Calibration.parsePercent('0'), 1000);
      expect(Calibration.parsePercent('2.5'), 1025);
      expect(Calibration.parsePercent('+2,5'), 1025);
      expect(Calibration.parsePercent('-1.5'), 985);
      expect(Calibration.parsePercent('-50'), 500);
      expect(Calibration.parsePercent(' 50 '), 1500);
    });

    test('parsePercent odbija nevalidno i van granica', () {
      for (final bad in ['', 'a', '2.55', '51', '-51', '--1', '1..5', '.5']) {
        expect(Calibration.parsePercent(bad), isNull, reason: bad);
      }
    });

    test('formatPercent', () {
      expect(Calibration.formatPercent(1000), '0');
      expect(Calibration.formatPercent(1025), '2.5');
      expect(Calibration.formatPercent(985), '-1.5');
      expect(Calibration.formatPercent(1100), '10');
    });

    test('parse i format su inverzni', () {
      for (var p = Calibration.minPermille; p <= Calibration.maxPermille; p++) {
        expect(Calibration.parsePercent(Calibration.formatPercent(p)), p);
      }
    });
  });

  group('FareCalculator kalibracija u promilima', () {
    const t = Tariff(startPrice: 0, pricePerKm: 100, waitingParaPerMin: 0, minPrice: 0);

    test('1000 promila ne menja distancu', () {
      expect(FareCalculator.calculate(tariff: t, distanceMeters: 1000, waitingSeconds: 0).kmPrice, 100);
    });

    test('+10% na 1000 m → 1100 m → 110 din', () {
      expect(
          FareCalculator.calculate(
                  tariff: t, distanceMeters: 1000, waitingSeconds: 0, calibrationPermille: 1100)
              .kmPrice,
          110);
    });

    test('-1,5% zaokružuje metre (.5 naviše), celobrojno', () {
      // 333 m * 0,985 = 328,005 → 328 m → 32,8 → 33 din
      expect(
          FareCalculator.calculate(
                  tariff: t, distanceMeters: 333, waitingSeconds: 0, calibrationPermille: 985)
              .kmPrice,
          33);
    });
  });
}
