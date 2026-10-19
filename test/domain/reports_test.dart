import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/ride_record.dart';
import 'package:taksimetar_balkan/domain/reports.dart';

RideRecord ride({
  int total = 300,
  int meters = 1000,
  int seconds = 600,
  String status = 'completed',
  bool noEnd = false,
}) {
  final start = DateTime.utc(2026, 10, 19, 10);
  return RideRecord(
    id: 1,
    startTime: start,
    endTime: noEnd ? null : start.add(Duration(seconds: seconds)),
    distanceMeters: meters,
    waitingSeconds: 60,
    startPrice: 200,
    kmPrice: 0,
    waitingPrice: 0,
    minPriceAdjustment: 0,
    totalPrice: total,
    status: status,
  );
}

void main() {
  group('ReportRange', () {
    final wed = DateTime(2026, 10, 21, 15, 30); // sreda

    test('dan', () {
      final r = ReportRange.containing(ReportPeriod.day, wed);
      expect(r.start, DateTime(2026, 10, 21));
      expect(r.end, DateTime(2026, 10, 22));
      expect(r.describe(), '21.10.2026.');
    });

    test('nedelja počinje ponedeljkom', () {
      final r = ReportRange.containing(ReportPeriod.week, wed);
      expect(r.start, DateTime(2026, 10, 19));
      expect(r.end, DateTime(2026, 10, 26));
      expect(r.describe(), '19.10.2026. – 25.10.2026.');
      final sunday = ReportRange.containing(ReportPeriod.week, DateTime(2026, 10, 25, 23));
      expect(sunday.start, DateTime(2026, 10, 19));
    });

    test('mesec i prelaz godine', () {
      final r = ReportRange.containing(ReportPeriod.month, DateTime(2026, 12, 31));
      expect(r.start, DateTime(2026, 12));
      expect(r.end, DateTime(2027, 1));
      expect(r.next().start, DateTime(2027, 1));
      expect(r.previous().start, DateTime(2026, 11));
      expect(r.describe(), '12/2026');
    });

    test('prethodni/sledeći dan i nedelja', () {
      final d = ReportRange.containing(ReportPeriod.day, DateTime(2026, 11, 1));
      expect(d.previous().start, DateTime(2026, 10, 31));
      expect(d.next().start, DateTime(2026, 11, 2));
      final w = ReportRange.containing(ReportPeriod.week, wed);
      expect(w.previous().start, DateTime(2026, 10, 12));
      expect(w.next().start, DateTime(2026, 10, 26));
    });
  });

  group('RideStats', () {
    test('prazno', () {
      final s = RideStats.of(const []);
      expect(s.rideCount, 0);
      expect(s.averagePerRide, 0);
      expect(s.perHour, 0);
      expect(s.perKm, 0);
    });

    test('zbirovi i proseci (celobrojno, .5 naviše)', () {
      final s = RideStats.of([
        ride(total: 300, meters: 2000, seconds: 900),
        ride(total: 451, meters: 3000, seconds: 900, status: 'interrupted'),
      ]);
      expect(s.rideCount, 2);
      expect(s.interruptedCount, 1);
      expect(s.totalPrice, 751);
      expect(s.distanceMeters, 5000);
      expect(s.durationSeconds, 1800);
      expect(s.waitingSeconds, 120);
      expect(s.averagePerRide, 376); // 375,5 → 376
      expect(s.perHour, 1502); // 751 za pola sata
      expect(s.perKm, 150); // 751 / 5 = 150,2
    });

    test('vožnja bez kraja ne ulazi u trajanje', () {
      final s = RideStats.of([ride(seconds: 600), ride(noEnd: true)]);
      expect(s.durationSeconds, 600);
      expect(s.rideCount, 2);
    });
  });
}
