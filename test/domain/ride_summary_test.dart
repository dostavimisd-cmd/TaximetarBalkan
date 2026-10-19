import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/ride_record.dart';
import 'package:taksimetar_balkan/domain/ride_summary.dart';

RideRecord ride({
  int seconds = 1800,
  int paused = 0,
  int meters = 15000,
  String? fixed,
  String status = 'completed',
}) {
  final start = DateTime.utc(2026, 10, 19, 10);
  return RideRecord(
    id: 1,
    startTime: start,
    endTime: start.add(Duration(seconds: seconds)),
    distanceMeters: meters,
    waitingSeconds: 120,
    startPrice: 250,
    kmPrice: 1200,
    waitingPrice: 40,
    minPriceAdjustment: 0,
    totalPrice: 1490,
    status: status,
    fixedRouteName: fixed,
    pausedSeconds: paused,
  );
}

void main() {
  test('trajanje bez pauze i prosečna brzina', () {
    final r = ride(seconds: 1800, paused: 600, meters: 10000);
    expect(r.activeDuration, const Duration(seconds: 1200));
    // 10 km za 20 min = 30 km/h
    expect(r.averageSpeedKmh, closeTo(30.0, 0.01));
    expect(RideSummary.speed(r), '30.0 km/h');
  });

  test('prekratka vožnja nema prosečnu brzinu', () {
    final r = ride(seconds: 20, meters: 100);
    expect(r.averageSpeedKmh, isNull);
    expect(RideSummary.speed(r), '—');
  });

  test('pauza duža od vožnje ne daje negativno trajanje', () {
    final r = ride(seconds: 100, paused: 500);
    expect(r.activeDuration, Duration.zero);
  });

  test('clock', () {
    expect(RideSummary.clock(65), '01:05');
    expect(RideSummary.clock(3725), '1:02:05');
  });

  test('tekst za deljenje: stavke, pauza, oznaka da nije fiskalni', () {
    final t = RideSummary.shareText(ride(paused: 125), header: 'TAXI MARKO');
    expect(t, startsWith('TAXI MARKO\n'));
    expect(t, contains('Distanca: 15.00 km'));
    expect(t, contains('Pauza: 02:05'));
    expect(t, contains('Kilometraža: 1200 din'));
    expect(t, contains('UKUPNO: 1490 din'));
    expect(t, contains('Ovo nije fiskalni račun.'));
    expect(t, isNot(contains('Relacija')));
  });

  test('fiksna relacija: bez razrade, prekinuta vožnja je označena', () {
    final t = RideSummary.shareText(ride(fixed: 'Aerodrom', status: 'interrupted'));
    expect(t, contains('Relacija: Aerodrom'));
    expect(t, isNot(contains('Kilometraža')));
    expect(t, contains('prekinuta'));
    expect(t, isNot(contains('Pauza')));
  });
}
