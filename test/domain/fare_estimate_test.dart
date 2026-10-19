import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/fare_estimate.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

void main() {
  const t = Tariff(startPrice: 250, pricePerKm: 80, waitingParaPerMin: 1333, minPrice: 400);

  test('start + km, bez čekanja', () {
    // 45,2 km * 80 = 3616 + 250
    expect(FareEstimate.forRoute(tariff: t, distanceMeters: 45200), 3866);
  });

  test('minimalna cena važi i u proceni', () {
    expect(FareEstimate.forRoute(tariff: t, distanceMeters: 500), 400);
  });

  test('kalibracija i fiksna relacija', () {
    expect(FareEstimate.forRoute(tariff: t, distanceMeters: 10000, calibrationPermille: 1100), 250 + 880);
    expect(FareEstimate.forRoute(tariff: t, distanceMeters: 45200, fixedPrice: 2500), 2500);
  });
}
