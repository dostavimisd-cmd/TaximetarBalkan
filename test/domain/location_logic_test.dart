import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/location_filter.dart';
import 'package:taksimetar_balkan/domain/smart_waiter.dart';
import 'package:taksimetar_balkan/domain/models/location_point.dart';

double addMetersToLat(double lat, double meters) {
  return lat + (meters * 180.0 / (pi * 6371000.0));
}

void main() {
  group('GPS Logika - Filter i SmartWaiter (Svi slučajevi)', () {
    late LocationFilter filter;
    late SmartWaiter waiter;
    final baseTime = DateTime.utc(2023, 1, 1, 12, 0, 0);
    const double baseLat = 44.8000;
    const double baseLon = 20.4000;

    setUp(() {
      filter = const LocationFilter(accuracyThresholdMeters: 15.0, maxSpeedKmh: 200.0, resetGapSeconds: 60);
      waiter = const SmartWaiter(waitingSpeedThresholdKmh: 8.0);
    });

    // --- STARI TESTOVI KOJE SMO VRATILI ---

    test('Filter: Odbacuje tačku sa lošom tačnošću (iako je prva)', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 20.0, speed: 0.0, timestamp: baseTime);
      expect(filter.isValid(p1, null), false);
    });

    test('Filter: Odbacuje nerealne skokove (teleportaciju od 5km za 10s uz GPS speed 10m/s)', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime);
      // Fizički razmak 5000m, razmak u vremenu 10s -> Izračunato 1800 km/h (pada na filteru)
      final p2 = LocationPoint(latitude: addMetersToLat(baseLat, 5000), longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime.add(const Duration(seconds: 10)));
      expect(filter.isValid(p2, p1), false);
    });

    test('Filter: Isti timestamp ili negativan razmak -> Odbacuje se bezbedno', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 5.0, timestamp: baseTime);
      final p2 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 5.0, timestamp: baseTime); 
      final p3 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 5.0, timestamp: baseTime.subtract(const Duration(seconds: 5))); 
      
      expect(filter.isValid(p2, p1), false);
      expect(filter.isValid(p3, p1), false);
    });

    test('SmartWaiter: Normalna vožnja (preko 8 km/h)', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime);
      final p2 = LocationPoint(latitude: addMetersToLat(baseLat, 100), longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime.add(const Duration(seconds: 10)));
      
      final result = waiter.process(p1, p2);
      expect(result.addedDistanceMeters, closeTo(100.0, 1.0));
      expect(result.addedWaitingMs, 0);
    });

    test('SmartWaiter: Vozilo stoji na semaforu', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 0.0, timestamp: baseTime);
      final p2 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 0.0, timestamp: baseTime.add(const Duration(seconds: 10)));
      
      final result = waiter.process(p1, p2);
      expect(result.addedDistanceMeters, 0.0);
      expect(result.addedWaitingMs, 10000);
    });

    // --- NOVI TESTOVI (Ivični slučajevi) ---

    test('SmartWaiter: GPS javlja speed 0, ali imamo 100m pomeranja za 10s (Bag senzora)', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 0.0, timestamp: baseTime);
      final p2 = LocationPoint(latitude: addMetersToLat(baseLat, 100), longitude: baseLon, accuracy: 5.0, speed: 0.0, timestamp: baseTime.add(const Duration(seconds: 10)));
      
      // Iako je GPS javio 0, waiter prepoznaje skok i računa 36km/h (preko 8)
      final result = waiter.process(p1, p2);
      expect(result.addedDistanceMeters, closeTo(100.0, 1.0));
      expect(result.addedWaitingMs, 0);
    });

    test('SmartWaiter: Rupa u signalu od 120s (Prolazak kroz tunel)', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime);
      
      // A) Brz tunel: 2000m za 120s (60 km/h izračunato)
      final p2Fast = LocationPoint(latitude: addMetersToLat(baseLat, 2000), longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime.add(const Duration(seconds: 120)));
      final resFast = waiter.process(p1, p2Fast);
      expect(resFast.addedDistanceMeters, closeTo(2000.0, 1.0));
      expect(resFast.addedWaitingMs, 0);

      // B) Spor tunel (Gužva): 100m za 120s (3 km/h izračunato)
      final p2Slow = LocationPoint(latitude: addMetersToLat(baseLat, 100), longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime.add(const Duration(seconds: 120)));
      final resSlow = waiter.process(p1, p2Slow);
      expect(resSlow.addedDistanceMeters, 0.0);
      expect(resSlow.addedWaitingMs, 120000);
    });

    test('SmartWaiter: Tačno na ivici (7.9 km/h i 8.1 km/h)', () {
      final p1 = LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 0.0, timestamp: baseTime);
      
      // 7.9 km/h (2.194 m/s). Speed iz senzora kontroliše ishod.
      final p79 = LocationPoint(latitude: addMetersToLat(baseLat, 21.94), longitude: baseLon, accuracy: 5.0, speed: 2.194, timestamp: baseTime.add(const Duration(seconds: 10)));
      final res79 = waiter.process(p1, p79);
      expect(res79.addedDistanceMeters, 0.0);
      expect(res79.addedWaitingMs, 10000); // Manje od 8, ide u čekanje

      // 8.1 km/h (2.25 m/s)
      final p81 = LocationPoint(latitude: addMetersToLat(baseLat, 22.5), longitude: baseLon, accuracy: 5.0, speed: 2.25, timestamp: baseTime.add(const Duration(seconds: 10)));
      final res81 = waiter.process(p1, p81);
      expect(res81.addedDistanceMeters, closeTo(22.5, 0.1));
      expect(res81.addedWaitingMs, 0); // Više od 8, ide u distancu
    });
  });
}