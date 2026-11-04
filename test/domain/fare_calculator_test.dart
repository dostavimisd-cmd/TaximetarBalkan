import 'package:flutter_test/flutter_test.dart';

// ZAMENI 'ime_tvog_projekta' sa tačnim nazivom iz pubspec.yaml
import 'package:taksimetar_balkan/domain/fare_calculator.dart';
import 'package:taksimetar_balkan/domain/models/fare_result.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

void main() {
  group('FareCalculator - Celobrojna Matematika', () {
    const defaultTariff = Tariff(
      startPrice: 150,
      pricePerKm: 80,
      waitingParaPerMin: 1000,
      minPrice: 200,
    );

    test('Vožnja bez čekanja (Nema minimalne cene)', () {
      // Ručni račun: Start 150. Km = (2000 * 80)/1000 = 160. Total = 310.
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 2000,
        waitingSeconds: 0,
      );
      expect(result.kmPrice, 160);
      expect(result.waitingPrice, 0);
      expect(result.minPriceAdjustment, 0);
      expect(result.totalPrice, 310);
      expect(result.startPrice + result.kmPrice + result.waitingPrice + result.minPriceAdjustment, result.totalPrice);
    });

    test('Vožnja sa čekanjem', () {
      // Ručni račun: Start 150. Km = (5000 * 80)/1000 = 400. Cekanje = (300 * 10)/60 = 50. Total = 600.
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 5000,
        waitingSeconds: 300,
      );
      expect(result.kmPrice, 400);
      expect(result.waitingPrice, 50);
      expect(result.totalPrice, 600);
      expect(result.startPrice + result.kmPrice + result.waitingPrice + result.minPriceAdjustment, result.totalPrice);
    });

    test('Minimalna cena i adjustment', () {
      // Ručni račun: Start 150. Km = (100 * 80)/1000 = 8. Ukupno 158. Min je 200. Adjustment = 42.
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 100,
        waitingSeconds: 0,
      );
      expect(result.kmPrice, 8);
      expect(result.totalPrice, 200);
      expect(result.minPriceAdjustment, 42);
      expect(result.isMinPriceApplied, true);
      expect(result.startPrice + result.kmPrice + result.waitingPrice + result.minPriceAdjustment, result.totalPrice);
    });

    test('Kalibracija različita od 1.0', () {
      // Ručni račun: Dist = 1000 * 1.05 = 1050m. Km = (1050 * 80)/1000 = 84. Total = 150 + 84 = 234.
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 1000,
        waitingSeconds: 0,
        calibrationPermille: 1050,
      );
      expect(result.kmPrice, 84);
      expect(result.totalPrice, 234);
    });

    test('Nula km i minuta', () {
      // Ručni račun: Start 150. Sve nula. Min 200. Adjustment 50.
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 0,
        waitingSeconds: 0,
      );
      expect(result.kmPrice, 0);
      expect(result.totalPrice, 200);
      expect(result.minPriceAdjustment, 50);
    });

    test('Granica zaokruživanja na .5', () {
      // Distanca: 1256m * 80 = 100480. 100480 / 1000 = 100.48 -> 100.
      // Distanca: 1257m * 80 = 100560. 100560 / 1000 = 100.56 -> 101.
      // Cekanje: 32s * 10 = 320. 320 / 60 = 5.33 -> 5.
      // Cekanje: 33s * 10 = 330. 330 / 60 = 5.5 -> 6.
      final result1 = FareCalculator.calculate(tariff: defaultTariff, distanceMeters: 1256, waitingSeconds: 32);
      expect(result1.kmPrice, 100);
      expect(result1.waitingPrice, 5);

      final result2 = FareCalculator.calculate(tariff: defaultTariff, distanceMeters: 1257, waitingSeconds: 33);
      expect(result2.kmPrice, 101);
      expect(result2.waitingPrice, 6);
    });

    test('Veliki iznosi (izbegavanje overflow-a)', () {
      // Ručni račun: Start 150. Dist = 100,000 m (100km). Km = (100,000 * 80)/1000 = 8000. 
      // Cekanje 36000s (10 sati). Cekanje = (36000 * 10)/60 = 6000. Total = 150 + 8000 + 6000 = 14150.
      final result = FareCalculator.calculate(
        tariff: defaultTariff,
        distanceMeters: 100000,
        waitingSeconds: 36000,
      );
      expect(result.kmPrice, 8000);
      expect(result.waitingPrice, 6000);
      expect(result.totalPrice, 14150);
    });

    test('Nevažeći ulazi bacaju grešku', () {
      expect(() => FareCalculator.calculate(tariff: defaultTariff, distanceMeters: -10, waitingSeconds: 0), throwsArgumentError);
      expect(() => FareCalculator.calculate(tariff: defaultTariff, distanceMeters: 10, waitingSeconds: -5), throwsArgumentError);
      expect(() => FareCalculator.calculate(tariff: defaultTariff, distanceMeters: 10, waitingSeconds: 0, calibrationPermille: 0), throwsArgumentError);
    });
  });

  test('čekanje sa decimalama: 13,4 din/min (1340 para)', () {
    const t = Tariff(
      startPrice: 0,
      pricePerKm: 0,
      waitingParaPerMin: 1340,
      minPrice: 0,
    );
    // 90 s * 13,4 / 60 = 20,1 → 20
    expect(FareCalculator.calculate(tariff: t, distanceMeters: 0, waitingSeconds: 90).waitingPrice, 20);
    // pun sat = 60 * 13,4 = 804
    expect(FareCalculator.calculate(tariff: t, distanceMeters: 0, waitingSeconds: 3600).waitingPrice, 804);
    // 800 din/h = 13,33 din/min (1333 para): sat = 799,8 → 800
    const hourly = Tariff(startPrice: 0, pricePerKm: 0, waitingParaPerMin: 1333, minPrice: 0);
    expect(FareCalculator.calculate(tariff: hourly, distanceMeters: 0, waitingSeconds: 3600).waitingPrice, 800);
  });

  test('fiksna cena: jedna stavka, bez km i čekanja', () {
    final f = FareCalculator.fixed(2000);
    expect(f.totalPrice, 2000);
    expect(f.startPrice, 2000);
    expect(f.kmPrice + f.waitingPrice + f.minPriceAdjustment, 0);
    expect(() => FareCalculator.fixed(0), throwsArgumentError);
  });

  group('Prvi kilometar', () {
    const base = Tariff(
      startPrice: 200,
      pricePerKm: 100,
      waitingParaPerMin: 0,
      minPrice: 0,
    );
    FareResult calc(Tariff t, int m, {int cal = 1000}) => FareCalculator.calculate(
        tariff: t, distanceMeters: m, waitingSeconds: 0, calibrationPermille: cal);

    test('bez cene prvog km: isto kao ranije', () {
      expect(calc(base, 2500).kmPrice, 250);
    });

    test('0 = prvi km uračunat u start', () {
      final t = base.copyWith(firstKmPrice: 0);
      expect(calc(t, 600).kmPrice, 0);
      expect(calc(t, 1000).kmPrice, 0);
      expect(calc(t, 2500).kmPrice, 150);
      expect(calc(t, 2500).totalPrice, 350);
    });

    test('> 0 = prvi km po svojoj ceni, ostatak po ceni po km', () {
      final t = base.copyWith(firstKmPrice: 300);
      expect(calc(t, 500).kmPrice, 150);
      expect(calc(t, 2500).kmPrice, 300 + 150);
      // zaokruživanje jednom, na zbir: 1005 m = 300 + 0,5 → 301
      expect(calc(t, 1005).kmPrice, 301);
    });

    test('prvi km se meri posle kalibracije', () {
      final t = base.copyWith(firstKmPrice: 0);
      // 1000 m * 1,1 = 1100 m → 100 m po 100 din/km = 10
      expect(calc(t, 1000, cal: 1100).kmPrice, 10);
    });

    test('negativna cena prvog km nije ispravna; brisanje vraća null', () {
      expect(base.copyWith(firstKmPrice: -1).validate(), isNotNull);
      expect(base.copyWith(firstKmPrice: 5).copyWith(clearFirstKm: true).firstKmPrice, isNull);
    });
  });

  group('Doplate', () {
    const t = Tariff(startPrice: 100, pricePerKm: 0, waitingParaPerMin: 0, minPrice: 400);

    test('dodaju se posle minimalne cene', () {
      final base = FareCalculator.calculate(tariff: t, distanceMeters: 0, waitingSeconds: 0);
      expect(base.totalPrice, 400);
      final f = FareCalculator.withExtras(base, 150);
      expect(f.minPriceAdjustment, 300);
      expect(f.extrasPrice, 150);
      expect(f.totalPrice, 550);
    });

    test('na fiksnu cenu; 0 ne menja ništa; negativno baca', () {
      expect(FareCalculator.withExtras(FareCalculator.fixed(1500), 200).totalPrice, 1700);
      final b = FareCalculator.fixed(1500);
      expect(identical(FareCalculator.withExtras(b, 0), b), isTrue);
      expect(() => FareCalculator.withExtras(b, -1), throwsArgumentError);
    });
  });
}
