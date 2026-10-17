import 'package:flutter_test/flutter_test.dart';
// ZAMENI 'taksimetar_balkan' ako ti se projekat zove drugačije
import 'package:taksimetar_balkan/domain/ride_tracker.dart';
import 'package:taksimetar_balkan/domain/models/location_point.dart';

void main() {
  group('RideTracker - GPS logika i čekanje', () {
    late RideTracker tracker;
    final baseTime = DateTime(2023, 1, 1, 12, 0, 0);

    setUp(() {
      tracker = RideTracker(accuracyThresholdMeters: 15.0, waitingSpeedThresholdKmh: 8.0);
    });

    test('Odbacuje GPS tačke sa lošom tačnošću', () {
      tracker.processLocation(LocationPoint(latitude: 44.8, longitude: 20.4, accuracy: 5.0, timestamp: baseTime));
      
      // Loša tačka (tačnost 20m > 15m)
      tracker.processLocation(LocationPoint(
        latitude: 44.801, longitude: 20.401, accuracy: 20.0, timestamp: baseTime.add(const Duration(seconds: 10))
      ));

      expect(tracker.totalDistanceMeters, 0);
      expect(tracker.totalWaitingSeconds, 0);
    });

    test('Računa vreme čekanja kada vozilo stoji (brzina = 0)', () {
      tracker.processLocation(LocationPoint(latitude: 44.8, longitude: 20.4, accuracy: 5.0, timestamp: baseTime));
      
      // Isti koordinate 10 sekundi kasnije
      tracker.processLocation(LocationPoint(latitude: 44.8, longitude: 20.4, accuracy: 5.0, timestamp: baseTime.add(const Duration(seconds: 10))));

      expect(tracker.totalDistanceMeters, 0);
      expect(tracker.totalWaitingSeconds, 10);
    });

    test('Računa distancu kada se vozilo kreće iznad praga čekanja', () {
      tracker.processLocation(LocationPoint(latitude: 44.8000, longitude: 20.4000, accuracy: 5.0, timestamp: baseTime));
      
      // Tačka koja daje brzinu od oko 30-40 km/h (bez čekanja)
      // Koordinata pomerena za oko 111 metara, vreme +10 sekundi
      tracker.processLocation(LocationPoint(latitude: 44.8010, longitude: 20.4000, accuracy: 5.0, timestamp: baseTime.add(const Duration(seconds: 10))));

      expect(tracker.totalWaitingSeconds, 0);
      expect(tracker.totalDistanceMeters, greaterThan(100)); // Oko 111 metara
    });

    test('Prelazak iz kretanja u stajanje (semafor)', () {
      // 1. Početak
      tracker.processLocation(LocationPoint(latitude: 44.8000, longitude: 20.4000, accuracy: 5.0, timestamp: baseTime));
      // 2. Kretanje (brza vožnja, 10s)
      tracker.processLocation(LocationPoint(latitude: 44.8010, longitude: 20.4000, accuracy: 5.0, timestamp: baseTime.add(const Duration(seconds: 10))));
      // 3. Semafor (stajanje, 15s)
      tracker.processLocation(LocationPoint(latitude: 44.8010, longitude: 20.4000, accuracy: 5.0, timestamp: baseTime.add(const Duration(seconds: 25))));

      expect(tracker.totalWaitingSeconds, 15);
      expect(tracker.totalDistanceMeters, greaterThan(100));
    });
  });
}