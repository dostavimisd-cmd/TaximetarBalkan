import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/earnings_chart.dart';
import 'package:taksimetar_balkan/domain/models/ride_record.dart';
import 'package:taksimetar_balkan/domain/models/shift.dart';
import 'package:taksimetar_balkan/domain/models/shift_expense.dart';

/// Vožnja koja počinje u lokalno vreme [local] i traje 30 min.
RideRecord ride(DateTime local, int total, {int meters = 5000}) => RideRecord(
      id: local.millisecondsSinceEpoch,
      startTime: local.toUtc(),
      endTime: local.add(const Duration(minutes: 30)).toUtc(),
      distanceMeters: meters,
      waitingSeconds: 0,
      startPrice: total,
      kmPrice: 0,
      waitingPrice: 0,
      minPriceAdjustment: 0,
      totalPrice: total,
      status: 'completed',
    );

ShiftExpense expense(DateTime local, int amount) =>
    ShiftExpense(shiftId: 1, name: 'Gorivo', amount: amount, createdAt: local.toUtc());

void main() {
  // 09.11.2026. je ponedeljak.
  final monday = DateTime(2026, 11, 9);

  test('nedelja počinje ponedeljkom; mesec ima onoliko stubova koliko dana; godina 12', () {
    final w = ChartRange.containing(ChartPeriod.week, DateTime(2026, 11, 11, 15));
    expect(w.start, monday);
    expect(w.bucketCount, 7);
    expect(w.bucketOf(DateTime(2026, 11, 15, 23, 59)), 6);
    expect(w.bucketOf(DateTime(2026, 11, 16)), isNull);
    expect(ChartRange.containing(ChartPeriod.month, monday).bucketCount, 30);
    expect(ChartRange.containing(ChartPeriod.month, DateTime(2028, 2, 3)).bucketCount, 29);
    final y = ChartRange.containing(ChartPeriod.year, monday);
    expect(y.bucketCount, 12);
    expect(y.bucketOf(DateTime(2026, 12, 31, 23)), 11);
    expect(w.previous().start, DateTime(2026, 11, 2));
    expect(ChartRange.containing(ChartPeriod.month, monday).previous().start, DateTime(2026, 10));
  });

  test('stubovi, zbirovi, najbolji dan, prosek po radnom danu i promena', () {
    final range = ChartRange.containing(ChartPeriod.week, monday);
    final c = EarningsChart.build(
      range: range,
      rides: [
        ride(DateTime(2026, 11, 9, 8), 1000),
        ride(DateTime(2026, 11, 9, 17), 1500),
        ride(DateTime(2026, 11, 13, 17, 30), 4000),
        ride(DateTime(2026, 11, 16, 1), 9999), // sledeća nedelja: ne broji se
      ],
      expenses: [expense(DateTime(2026, 11, 13, 20), 2000)],
      shifts: const [],
      previousRides: [ride(DateTime(2026, 11, 3, 9), 5000)],
      nowUtc: DateTime.utc(2026, 11, 20),
    );
    expect(c.buckets.map((b) => b.earned), [2500, 0, 0, 0, 4000, 0, 0]);
    expect(c.buckets[4].expenses, 2000);
    expect(c.earned, 6500);
    expect(c.expenses, 2000);
    expect(c.remaining, 4500);
    expect(c.best!.start, DateTime(2026, 11, 13));
    expect(c.averagePerActiveBucket, 3250);
    expect(c.changePercent, 30);
    expect(c.stats.rideCount, 3);
    expect(c.stats.averagePerRide, 2167);
    expect(c.ridesByHour[17], 2);
    expect(c.bestHour, 17);
    // bez smena: po satu vožnje (3 × 30 min)
    expect(c.perHourFromShifts, isFalse);
    expect(c.perHour, 4333);
  });

  test('zarada po satu rada: samo deo smene u periodu, otvorena smena do sada', () {
    final range = ChartRange.containing(ChartPeriod.week, monday);
    final c = EarningsChart.build(
      range: range,
      rides: [ride(DateTime(2026, 11, 9, 8), 6000)],
      expenses: const [],
      shifts: [
        // počela u nedelju pre perioda: broji se od ponoći (2 h)
        Shift(id: 1, start: DateTime(2026, 11, 8, 22).toUtc(), end: DateTime(2026, 11, 9, 2).toUtc()),
        // u toku: do „sada” (4 h)
        Shift(id: 2, start: DateTime(2026, 11, 10, 6).toUtc()),
      ],
      previousRides: const [],
      nowUtc: DateTime(2026, 11, 10, 10).toUtc(),
    );
    expect(c.workSeconds, 6 * 3600);
    expect(c.perHourFromShifts, isTrue);
    expect(c.perHour, 1000);
    expect(c.changePercent, isNull);
  });

  test('pad u odnosu na prethodni period je negativan; prazan period nema najbolji', () {
    final range = ChartRange.containing(ChartPeriod.year, monday);
    final c = EarningsChart.build(
      range: range,
      rides: [ride(DateTime(2026, 3, 1, 10), 750)],
      expenses: const [],
      shifts: const [],
      previousRides: [ride(DateTime(2025, 5, 1, 10), 1000)],
      nowUtc: DateTime.utc(2026, 11, 11),
    );
    expect(c.buckets[2].earned, 750);
    expect(c.changePercent, -25);
    final empty = EarningsChart.build(
      range: range.next(),
      rides: const [],
      expenses: const [],
      shifts: const [],
      previousRides: const [],
      nowUtc: DateTime.utc(2026, 11, 11),
    );
    expect(empty.best, isNull);
    expect(empty.bestHour, isNull);
    expect(empty.averagePerActiveBucket, 0);
  });
}
