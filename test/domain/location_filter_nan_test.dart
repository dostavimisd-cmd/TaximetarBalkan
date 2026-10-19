import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/location_filter.dart';
import 'package:taksimetar_balkan/domain/models/location_point.dart';
import 'package:taksimetar_balkan/domain/ride_tracker.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

LocationPoint p(double lat, double lon, double acc, int sec) => LocationPoint(
      latitude: lat,
      longitude: lon,
      accuracy: acc,
      speed: 0,
      timestamp: DateTime.utc(2024, 1, 1).add(Duration(seconds: sec)),
    );

void main() {
  const filter = LocationFilter();

  test('U2: NaN i Infinity se odbacuju', () {
    expect(filter.isValid(p(double.nan, 20, 5, 0), null), false);
    expect(filter.isValid(p(44, double.infinity, 5, 0), null), false);
    expect(filter.isValid(p(44, 20, double.nan, 0), null), false);
    expect(filter.isValid(p(44, 20, 5, 0), null), true);
  });

  test('U2: NaN tačka ne kvari zbir distance', () {
    final t = RideTracker(
        tariff: const Tariff(
            id: 1, startPrice: 200, pricePerKm: 100, waitingPricePerMin: 10, minPrice: 0));
    t.processLocation(p(44.8, 20.4, 5, 0));
    t.processLocation(p(double.nan, 20.4, 5, 1));
    t.processLocation(p(44.8009, 20.4, 5, 10));
    expect(t.totalDistanceMeters.isFinite, true);
    expect(t.totalDistanceMeters, greaterThan(50));
  });
}
