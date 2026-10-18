import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/location_filter.dart';
import 'package:taksimetar_balkan/domain/smart_waiter.dart';
import 'package:taksimetar_balkan/domain/models/location_point.dart';

double addMetersToLat(double lat, double meters) =>
    lat + (meters * 180.0 / (pi * 6371000.0));

LocationPoint pt(double meters, int seconds,
    {double accuracy = 5.0, double speed = 0.0}) {
  return LocationPoint(
    latitude: addMetersToLat(44.8, meters),
    longitude: 20.4,
    accuracy: accuracy,
    speed: speed,
    timestamp: DateTime.utc(2023, 1, 1, 12, 0, 0).add(Duration(seconds: seconds)),
  );
}

void main() {
  group('LocationFilter', () {
    const filter = LocationFilter(
        accuracyThresholdMeters: 15.0, maxSpeedKmh: 200.0, resetGapSeconds: 60);

    test('loša tačnost (20 m) se odbacuje, tačno 15,0 m prolazi', () {
      expect(filter.isValid(pt(0, 0, accuracy: 20.0), null), false);
      expect(filter.isValid(pt(0, 0, accuracy: 15.0), null), true);
    });

    test('loša tačnost nove tačke se odbacuje i kad postoji prethodna', () {
      expect(filter.isValid(pt(10, 5, accuracy: 30.0), pt(0, 0)), false);
    });

    test('isti timestamp i negativan razmak se odbacuju', () {
      expect(filter.isValid(pt(0, 0), pt(0, 0)), false);
      expect(filter.isValid(pt(0, -5), pt(0, 0)), false);
    });

    test('teleportacija: 5 km za 10 s uz GPS speed 10 m/s se odbacuje', () {
      expect(filter.isValid(pt(5000, 10, speed: 10.0), pt(0, 0, speed: 10.0)), false);
    });

    test('posle rupe od 61 s skok se prihvata kao reset', () {
      expect(filter.isValid(pt(5000, 61), pt(0, 0)), true);
    });

    test('normalna vožnja (100 m za 10 s) prolazi', () {
      expect(filter.isValid(pt(100, 10, speed: 10.0), pt(0, 0, speed: 10.0)), true);
    });
  });

  group('SmartWaiter', () {
    const waiter = SmartWaiter(waitingSpeedThresholdKmh: 8.0);

    test('semafor: stoji 10 s -> čekanje, distanca 0', () {
      final p1 = pt(0, 0);
      final r = waiter.process(p1, pt(0, 10), p1);
      expect(r.addedDistanceMeters, 0.0);
      expect(r.addedWaitingMs, 10000);
    });

    test('rupa od 2 sata dok vozilo stoji: čekanje ograničeno na 5 min', () {
      final p1 = pt(0, 0);
      final r = waiter.process(p1, pt(0, 7200), p1);
      expect(r.addedDistanceMeters, 0.0);
      expect(r.addedWaitingMs, 300000);
    });

    test('normalna vožnja: 100 m za 10 s -> distanca, čekanje 0', () {
      final p1 = pt(0, 0, speed: 10.0);
      final r = waiter.process(p1, pt(100, 10, speed: 10.0), p1);
      expect(r.addedDistanceMeters, closeTo(100.0, 1.0));
      expect(r.addedWaitingMs, 0);
    });

    test('bag senzora: GPS speed 0, ali pomak 100 m za 10 s -> distanca', () {
      final p1 = pt(0, 0);
      final r = waiter.process(p1, pt(100, 10, speed: 0.0), p1);
      expect(r.addedDistanceMeters, closeTo(100.0, 1.0));
      expect(r.addedWaitingMs, 0);
    });

    test('rupa od 120 s: brzo (2 km) -> distanca, sporo (100 m) -> čekanje', () {
      final p1 = pt(0, 0, speed: 10.0);
      final fast = waiter.process(p1, pt(2000, 120, speed: 10.0), p1);
      expect(fast.addedDistanceMeters, closeTo(2000.0, 2.0));
      expect(fast.addedWaitingMs, 0);

      final slow = waiter.process(p1, pt(100, 120, speed: 10.0), p1);
      expect(slow.addedDistanceMeters, 0.0);
      expect(slow.addedWaitingMs, 120000);
    });

    test('granica 8 km/h: 7,9 ide u čekanje, 8,1 u distancu (brzina iz pomaka)', () {
      final p1 = pt(0, 0);
      final slow = waiter.process(p1, pt(21.94, 10), p1); // 7,9 km/h
      expect(slow.addedDistanceMeters, 0.0);
      expect(slow.addedWaitingMs, 10000);

      final fast = waiter.process(p1, pt(22.5, 10), p1); // 8,1 km/h
      expect(fast.addedDistanceMeters, closeTo(22.5, 0.2));
      expect(fast.addedWaitingMs, 0);
    });
  });
}