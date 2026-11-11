import 'models/ride_record.dart';
import 'models/shift.dart';
import 'models/shift_expense.dart';
import 'reports.dart';

enum ChartPeriod { week, month, year }

/// Lokalni interval grafikona [start, end); nedelja počinje ponedeljkom.
/// Stub je dan (nedelja, mesec) ili mesec (godina).
class ChartRange {
  final ChartPeriod period;
  final DateTime start; // lokalno
  final DateTime end; // lokalno, isključeno

  const ChartRange(this.period, this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is ChartRange && other.period == period && other.start == start;

  @override
  int get hashCode => Object.hash(period, start);

  factory ChartRange.containing(ChartPeriod period, DateTime local) {
    switch (period) {
      case ChartPeriod.week:
        final r = ReportRange.containing(ReportPeriod.week, local);
        return ChartRange(period, r.start, r.end);
      case ChartPeriod.month:
        final r = ReportRange.containing(ReportPeriod.month, local);
        return ChartRange(period, r.start, r.end);
      case ChartPeriod.year:
        return ChartRange(period, DateTime(local.year), DateTime(local.year + 1));
    }
  }

  ChartRange previous() =>
      ChartRange.containing(period, DateTime(start.year, start.month, start.day - 1));

  ChartRange next() => ChartRange.containing(period, end);

  int get startUtcMs => start.toUtc().millisecondsSinceEpoch;
  int get endUtcMs => end.toUtc().millisecondsSinceEpoch;

  /// Stubovi su dani (nedelja, mesec) ili meseci (godina).
  bool get daily => period != ChartPeriod.year;

  int get bucketCount => switch (period) {
    ChartPeriod.week => 7,
    ChartPeriod.month => DateTime(start.year, start.month + 1, 0).day,
    ChartPeriod.year => 12,
  };

  /// Početak stuba [i] (lokalno).
  DateTime bucketStart(int i) => daily
      ? DateTime(start.year, start.month, start.day + i)
      : DateTime(start.year, i + 1);

  /// Indeks stuba za lokalno vreme, ili null ako je van intervala.
  int? bucketOf(DateTime local) {
    if (local.isBefore(start) || !local.isBefore(end)) return null;
    if (!daily) return local.month - 1;
    final day = DateTime(local.year, local.month, local.day);
    // razlika u kalendarskim danima (otporno na letnje računanje vremena)
    return DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
  }

  String describe() {
    String two(int v) => v.toString().padLeft(2, '0');
    switch (period) {
      case ChartPeriod.week:
        final last = DateTime(end.year, end.month, end.day - 1);
        return '${two(start.day)}.${two(start.month)}. – ${two(last.day)}.${two(last.month)}.${last.year}.';
      case ChartPeriod.month:
        return '${two(start.month)}/${start.year}';
      case ChartPeriod.year:
        return '${start.year}.';
    }
  }
}

/// Jedan stub: zarada, troškovi i broj vožnji (celi dinari).
class ChartBucket {
  final DateTime start; // lokalno
  final int earned;
  final int expenses;
  final int rides;

  const ChartBucket(this.start, this.earned, this.expenses, this.rides);
}

/// Grafikon zarade (D3): stubovi po danu ili mesecu, zbirovi, zarada po
/// satu rada, poređenje sa prethodnim periodom i vožnje po satu u danu.
/// Samo čita završene vožnje i troškove smena; novac je ceo dinar.
class EarningsChart {
  final ChartRange range;
  final List<ChartBucket> buckets;
  final RideStats stats;
  final int expenses;

  /// Vreme smena u periodu (sekunde, deo smene van perioda se ne broji);
  /// 0 = nema smena, pa se zarada po satu računa po vremenu vožnji.
  final int workSeconds;

  /// Broj vožnji po satu početka (0–23, lokalno).
  final List<int> ridesByHour;

  /// Zarada u prethodnom periodu iste dužine.
  final int previousEarned;

  const EarningsChart({
    required this.range,
    required this.buckets,
    required this.stats,
    required this.expenses,
    required this.workSeconds,
    required this.ridesByHour,
    required this.previousEarned,
  });

  int get earned => stats.totalPrice;
  int get remaining => earned - expenses;

  /// Zarada po satu: po smenama ako ih ima, inače po vremenu u vožnji.
  int get perHour => workSeconds > 0 ? stats.perHourOver(workSeconds) : stats.perHour;

  bool get perHourFromShifts => workSeconds > 0;

  /// Stub sa najvećom zaradom; null ako nema zarade.
  ChartBucket? get best {
    ChartBucket? b;
    for (final x in buckets) {
      if (x.earned > 0 && (b == null || x.earned > b.earned)) b = x;
    }
    return b;
  }

  /// Prosek po stubu u kome je bilo zarade (radni dan ili mesec).
  int get averagePerActiveBucket {
    final active = buckets.where((b) => b.earned > 0).length;
    return active == 0 ? 0 : (earned * 2 + active) ~/ (2 * active);
  }

  /// Promena u odnosu na prethodni period u procentima (zaokruženo);
  /// null kad prethodni period nema zarade.
  int? get changePercent {
    if (previousEarned <= 0) return null;
    final diff = (earned - previousEarned) * 100;
    final r = (diff.abs() * 2 + previousEarned) ~/ (2 * previousEarned);
    return diff < 0 ? -r : r;
  }

  /// Sat početka sa najviše vožnji; null ako nema vožnji.
  int? get bestHour {
    int? h;
    for (var i = 0; i < 24; i++) {
      if (ridesByHour[i] > 0 && (h == null || ridesByHour[i] > ridesByHour[h])) h = i;
    }
    return h;
  }

  factory EarningsChart.build({
    required ChartRange range,
    required List<RideRecord> rides,
    required List<ShiftExpense> expenses,
    required List<Shift> shifts,
    required List<RideRecord> previousRides,
    required DateTime nowUtc,
  }) {
    final n = range.bucketCount;
    final earned = List.filled(n, 0);
    final spent = List.filled(n, 0);
    final count = List.filled(n, 0);
    final hours = List.filled(24, 0);
    final inRange = <RideRecord>[];
    for (final r in rides) {
      final local = r.startTime.toLocal();
      final i = range.bucketOf(local);
      if (i == null) continue;
      inRange.add(r);
      earned[i] += r.totalPrice;
      count[i]++;
      hours[local.hour]++;
    }
    var expenseTotal = 0;
    for (final e in expenses) {
      final at = e.createdAt;
      if (at == null) continue;
      final i = range.bucketOf(at.toLocal());
      if (i == null) continue;
      spent[i] += e.amount;
      expenseTotal += e.amount;
    }
    final from = range.start.toUtc();
    final to = range.end.toUtc();
    var work = 0;
    for (final s in shifts) {
      final a = s.start.isAfter(from) ? s.start : from;
      final endOr = s.endOr(nowUtc);
      final b = endOr.isBefore(to) ? endOr : to;
      if (b.isAfter(a)) work += b.difference(a).inSeconds;
    }
    return EarningsChart(
      range: range,
      buckets: [
        for (var i = 0; i < n; i++) ChartBucket(range.bucketStart(i), earned[i], spent[i], count[i]),
      ],
      stats: RideStats.of(inRange),
      expenses: expenseTotal,
      workSeconds: work,
      ridesByHour: hours,
      previousEarned: previousRides.fold(0, (s, r) => s + r.totalPrice),
    );
  }
}
