import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/gap_info.dart';
import 'package:taksimetar_balkan/domain/models/location_point.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';
import 'package:taksimetar_balkan/domain/ride_tracker.dart';

LocationPoint pt(double meters, int seconds, {double speed = 0}) => LocationPoint(
      latitude: 44.8 + meters * 180.0 / (pi * 6371000.0),
      longitude: 20.4,
      accuracy: 5,
      speed: speed,
      timestamp: DateTime.utc(2024, 1, 1, 12).add(Duration(seconds: seconds)),
    );

RideTracker tracker() => RideTracker(
    tariff: const Tariff(
        startPrice: 200, pricePerKm: 100, waitingParaPerMin: 1000, minPrice: 0));

void main() {
  test('normalan tok (rupa <= 10 s) nema GapInfo', () {
    final t = tracker();
    t.processLocation(pt(0, 0, speed: 10));
    t.processLocation(pt(10, 1, speed: 10));
    t.processLocation(pt(20, 9, speed: 10));
    expect(t.lastGap, isNull);
  });

  test('rupa 60 s u mestu → naplaćena kao čekanje', () {
    final t = tracker();
    t.processLocation(pt(0, 0));
    t.processLocation(pt(0, 5));
    t.processLocation(pt(2, 65)); // 60 s, 2 m: sporo
    final gap = t.lastGap!;
    expect(gap.kind, GapInfo.kindWaiting);
    expect(gap.durationMs, 60000);
    expect(gap.addedWaitingMs, 60000);
    expect(gap.addedDistanceMeters, 0);
    expect(gap.startedAt, DateTime.utc(2024, 1, 1, 12, 0, 5));
  });

  test('rupa 30 s uz kretanje (~72 km/h) → vazdušna linija u distancu', () {
    final t = tracker();
    t.processLocation(pt(0, 0, speed: 20));
    t.processLocation(pt(20, 1, speed: 20));
    t.processLocation(pt(620, 31, speed: 20)); // 600 m za 30 s
    final gap = t.lastGap!;
    expect(gap.kind, GapInfo.kindDistance);
    expect(gap.addedDistanceMeters, closeTo(600, 2));
    expect(gap.addedWaitingMs, 0);
  });

  test('rupa 70 s sa skokom nemoguće brzine → ništa se ne dodaje (skipped)', () {
    final t = tracker();
    t.processLocation(pt(0, 0, speed: 10));
    t.processLocation(pt(10, 1, speed: 10));
    final before = t.totalDistanceMeters;
    t.processLocation(pt(20000, 71, speed: 10)); // 20 km za 70 s ≈ 1000 km/h
    expect(t.lastGap!.kind, GapInfo.kindSkipped);
    expect(t.totalDistanceMeters, before);
  });

  test('lastGap se briše posle sledeće obične tačke', () {
    final t = tracker();
    t.processLocation(pt(0, 0));
    t.processLocation(pt(0, 60));
    expect(t.lastGap, isNotNull);
    t.processLocation(pt(0, 61));
    expect(t.lastGap, isNull);
  });
}
