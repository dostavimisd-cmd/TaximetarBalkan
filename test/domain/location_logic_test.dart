import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/location_point.dart';
import 'package:taksimetar_balkan/domain/ride_tracker.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

double addMetersToLat(double lat, double meters) {
  return lat + (meters * 180.0 / (pi * 6371000.0));
}

void main() {
  group('RideTracker integracioni testovi (Prozor)', () {
    const baseLat = 44.8000;
    const baseLon = 20.4000;
    final baseTime = DateTime.utc(2023, 1, 1, 12, 0, 0);
    const tariff = Tariff(id: 1, startPrice: 150, pricePerKm: 80, waitingPricePerMin: 10, minPrice: 200);

    test('a) 60 tačaka, speed 0, šum 3m napred-nazad', () {
      final tracker = RideTracker(tariff: tariff);
      // Šum naizmenično (0m, 3m, 0m, 3m). Brzina susednih je 10.8 km/h, ali u 4s prozoru je ~0 km/h.
      for (int i = 0; i <= 60; i++) {
        double offsetMeters = (i % 2 == 0) ? 0.0 : 3.0;
        tracker.processLocation(LocationPoint(
          latitude: addMetersToLat(baseLat, offsetMeters), 
          longitude: baseLon, accuracy: 5.0, speed: 0.0, 
          timestamp: baseTime.add(Duration(seconds: i))
        ));
      }
      
      // Sav šum mora otići u čekanje
      expect(tracker.totalDistanceMeters, lessThan(5.0)); // Distanca praktično 0
      expect(tracker.totalWaitingMs, closeTo(60000, 1000));
    });

    test('b) Vožnja 9 km/h (2.5 m/s), speed 0', () {
      final tracker = RideTracker(tariff: tariff);
      for (int i = 0; i <= 60; i++) {
        tracker.processLocation(LocationPoint(
          latitude: addMetersToLat(baseLat, i * 2.5), 
          longitude: baseLon, accuracy: 5.0, speed: 0.0, 
          timestamp: baseTime.add(Duration(seconds: i))
        ));
      }
      
      expect(tracker.totalDistanceMeters, closeTo(150.0, 5.0)); // 60 * 2.5 = 150
      expect(tracker.totalWaitingMs, lessThan(4000)); // Do 4s lag na samom početku
    });

    test('c) Vožnja 36 km/h (10 m/s), speed 0', () {
      final tracker = RideTracker(tariff: tariff);
      for (int i = 0; i <= 60; i++) {
        tracker.processLocation(LocationPoint(
          latitude: addMetersToLat(baseLat, i * 10.0), 
          longitude: baseLon, accuracy: 5.0, speed: 0.0, 
          timestamp: baseTime.add(Duration(seconds: i))
        ));
      }
      
      expect(tracker.totalDistanceMeters, closeTo(600.0, 5.0));
      expect(tracker.totalWaitingMs, lessThan(2000));
    });

    test('d) Prelaz iz stajanja u vožnju (Lag klasifikacije)', () {
      final tracker = RideTracker(tariff: tariff);
      // Stoji 10s
      for (int i = 0; i <= 10; i++) {
        tracker.processLocation(LocationPoint(latitude: baseLat, longitude: baseLon, accuracy: 5.0, speed: 0.0, timestamp: baseTime.add(Duration(seconds: i))));
      }
      expect(tracker.totalDistanceMeters, 0.0);
      
      // Krece ubrzanjem: pređe 10 metara u prvoj sekundi (36 km/h)
      // Iako je prozor 4 sekunde (gde su prve 3 stajale, a u 4. prešao 10m), 
      // 10 metara u 4 sekunde = 2.5 m/s = 9.0 km/h. To je odma iznad 8 km/h!
      tracker.processLocation(LocationPoint(latitude: addMetersToLat(baseLat, 10.0), longitude: baseLon, accuracy: 5.0, speed: 0.0, timestamp: baseTime.add(const Duration(seconds: 11))));
      
      /* KOMENTAR: 
         Zbog praga od 8 km/h (2.22 m/s), prelaz iz mirovanja u normalnu 
         gradsku vožnju kasni MAKSIMALNO 1 sekundu. Čak i osrednje ubrzanje 
         preskoči prag unutar prozora odmah. Sistem reaguje ekstremno brzo. */
      expect(tracker.totalDistanceMeters, closeTo(10.0, 0.1));
    });

    test('e) Restore iz Snapshot-a vs Neprekinuta vožnja', () {
      final trackerContinuous = RideTracker(tariff: tariff);
      final trackerRestored = RideTracker(tariff: tariff);

      // Obojica voze 50s po 10 m/s
      for (int i = 0; i <= 50; i++) {
        trackerContinuous.processLocation(LocationPoint(latitude: addMetersToLat(baseLat, i * 10.0), longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime.add(Duration(seconds: i))));
      }

      // Prekid drugog, učitavanje snapshot-a
      trackerRestored.restoreFromSnapshot(
        restoredDistance: trackerContinuous.totalDistanceMeters,
        restoredWaitingMs: trackerContinuous.totalWaitingMs,
        lastLat: trackerContinuous.lastValidPoint!.latitude,
        lastLon: trackerContinuous.lastValidPoint!.longitude,
        lastTimestamp: trackerContinuous.lastValidPoint!.timestamp,
      );

      // Nastavljaju obojica do 60s
      for (int i = 51; i <= 60; i++) {
        final point = LocationPoint(latitude: addMetersToLat(baseLat, i * 10.0), longitude: baseLon, accuracy: 5.0, speed: 10.0, timestamp: baseTime.add(Duration(seconds: i)));
        trackerContinuous.processLocation(point);
        trackerRestored.processLocation(point);
      }

      final loss = (trackerContinuous.totalDistanceMeters - trackerRestored.totalDistanceMeters).abs();
      // Gubitak usled restarta i poništenog prozora mora biti minimalan
      expect(loss, lessThan(0.5));
    });
  });
}