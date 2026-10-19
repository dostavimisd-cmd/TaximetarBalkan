import 'models/ride_record.dart';

enum ReportPeriod { day, week, month }

/// Lokalni interval [start, end) za izveštaj; nedelja počinje ponedeljkom.
class ReportRange {
  final ReportPeriod period;
  final DateTime start; // lokalno
  final DateTime end; // lokalno, isključeno

  const ReportRange(this.period, this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.period == period && other.start == start;

  @override
  int get hashCode => Object.hash(period, start);

  factory ReportRange.containing(ReportPeriod period, DateTime local) {
    final day = DateTime(local.year, local.month, local.day);
    switch (period) {
      case ReportPeriod.day:
        return ReportRange(period, day, DateTime(day.year, day.month, day.day + 1));
      case ReportPeriod.week:
        final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
        return ReportRange(period, monday, DateTime(monday.year, monday.month, monday.day + 7));
      case ReportPeriod.month:
        return ReportRange(period, DateTime(day.year, day.month), DateTime(day.year, day.month + 1));
    }
  }

  ReportRange previous() =>
      ReportRange.containing(period, DateTime(start.year, start.month, start.day - 1));

  ReportRange next() => ReportRange.containing(period, end);

  /// Za upit nad bazom (vreme u bazi je UTC ms).
  int get startUtcMs => start.toUtc().millisecondsSinceEpoch;
  int get endUtcMs => end.toUtc().millisecondsSinceEpoch;

  String describe() {
    String two(int v) => v.toString().padLeft(2, '0');
    String d(DateTime t) => '${two(t.day)}.${two(t.month)}.${t.year}.';
    switch (period) {
      case ReportPeriod.day:
        return d(start);
      case ReportPeriod.week:
        final last = DateTime(end.year, end.month, end.day - 1);
        return '${d(start)} – ${d(last)}';
      case ReportPeriod.month:
        return '${two(start.month)}/${start.year}';
    }
  }
}

/// Zbir vožnji za period. Sve vrednosti novca su celi dinari; proseci su
/// zaokruženi (.5 naviše) i služe samo za prikaz.
class RideStats {
  final int rideCount;
  final int interruptedCount;
  final int totalPrice;
  final int distanceMeters;
  final int durationSeconds; // zbir trajanja vožnji (bez vožnji bez kraja)
  final int waitingSeconds;

  const RideStats({
    required this.rideCount,
    required this.interruptedCount,
    required this.totalPrice,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.waitingSeconds,
  });

  factory RideStats.of(Iterable<RideRecord> rides) {
    var count = 0, interrupted = 0, total = 0, meters = 0, seconds = 0, waiting = 0;
    for (final r in rides) {
      count++;
      if (r.isInterrupted) interrupted++;
      total += r.totalPrice;
      meters += r.distanceMeters;
      waiting += r.waitingSeconds;
      final d = r.duration;
      if (d != null && !d.isNegative) seconds += d.inSeconds;
    }
    return RideStats(
      rideCount: count,
      interruptedCount: interrupted,
      totalPrice: total,
      distanceMeters: meters,
      durationSeconds: seconds,
      waitingSeconds: waiting,
    );
  }

  static int _div(int a, int b) => b <= 0 ? 0 : (a * 2 + b) ~/ (2 * b);

  /// Prosečna cena vožnje.
  int get averagePerRide => _div(totalPrice, rideCount);

  /// Zarada po satu vožnje (vreme u vožnji, ne smena).
  int get perHour => _div(totalPrice * 3600, durationSeconds);

  /// Zarada po satu za zadato vreme (npr. trajanje smene).
  int perHourOver(int seconds) => _div(totalPrice * 3600, seconds);

  /// Zarada po kilometru.
  int get perKm => _div(totalPrice * 1000, distanceMeters);
}
