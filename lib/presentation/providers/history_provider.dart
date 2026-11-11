import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database_helper.dart';
import '../../data/repositories/ride_history_repository_impl.dart';
import '../../data/repositories/shift_repository_impl.dart';
import '../../domain/earnings_chart.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/shift_expense.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../domain/models/gap_info.dart';
import '../../domain/models/ride_record.dart';
import '../../domain/reports.dart';
import '../../domain/repositories/ride_history_repository.dart';

final rideHistoryRepositoryProvider = Provider<RideHistoryRepository>(
  (ref) => RideHistoryRepositoryImpl(() => DatabaseHelper.instance.database),
);

/// Istorija se čita svaki put kad se ekran otvori (autoDispose).
final rideHistoryProvider = FutureProvider.autoDispose<List<RideRecord>>(
  (ref) => ref.read(rideHistoryRepositoryProvider).getAll(),
);

/// Grafikon zarade za period (D3): vožnje, troškovi, smene i prethodni period.
final earningsChartProvider = FutureProvider.autoDispose
    .family<EarningsChart, ChartRange>((ref, range) async {
      final rides = ref.read(rideHistoryRepositoryProvider);
      final shifts = ref.read(shiftRepositoryProvider);
      final prev = range.previous();
      return EarningsChart.build(
        range: range,
        rides: await rides.getBetween(range.startUtcMs, range.endUtcMs),
        expenses: await shifts.getExpensesBetween(range.startUtcMs, range.endUtcMs),
        shifts: await shifts.getAll(),
        previousRides: await rides.getBetween(prev.startUtcMs, prev.endUtcMs),
        nowUtc: DateTime.now().toUtc(),
      );
    });

final rideGapsProvider = FutureProvider.autoDispose.family<List<GapInfo>, int>(
  (ref, rideId) => ref.read(rideHistoryRepositoryProvider).getGaps(rideId),
);

/// Vožnje u periodu izveštaja (ključ: početak perioda u UTC ms + vrsta).
final reportRidesProvider = FutureProvider.autoDispose
    .family<List<RideRecord>, ReportRange>(
      (ref, range) => ref
          .read(rideHistoryRepositoryProvider)
          .getBetween(range.startUtcMs, range.endUtcMs),
    );

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepositoryImpl(() => DatabaseHelper.instance.database),
);

/// Sve smene, najnovija prva (osvežava se posle početka/kraja smene).
final shiftsProvider = FutureProvider.autoDispose<List<Shift>>(
  (ref) => ref.read(shiftRepositoryProvider).getAll(),
);

/// Vožnje u smeni; otvorena smena se računa do sada.
final shiftRidesProvider = FutureProvider.autoDispose
    .family<List<RideRecord>, Shift>(
      (ref, shift) => ref
          .read(rideHistoryRepositoryProvider)
          .getBetween(
            shift.start.millisecondsSinceEpoch,
            shift.endOr(DateTime.now().toUtc()).millisecondsSinceEpoch + 1,
          ),
    );

/// Otvorena smena ili null (meni, cilj).
final currentShiftProvider = FutureProvider.autoDispose<Shift?>(
  (ref) => ref.read(shiftRepositoryProvider).current(),
);

/// Troškovi smene (G2).
final shiftExpensesProvider = FutureProvider.autoDispose
    .family<List<ShiftExpense>, int>(
      (ref, shiftId) => ref.read(shiftRepositoryProvider).getExpenses(shiftId),
    );

/// Zarada za cilj (G3): otvorena smena, a bez nje današnji dan (lokalno).
final goalEarnedProvider = FutureProvider.autoDispose<int>((ref) async {
  final shift = await ref.read(shiftRepositoryProvider).current();
  final now = DateTime.now();
  final int from;
  final int to;
  if (shift != null) {
    from = shift.start.millisecondsSinceEpoch;
    to = now.toUtc().millisecondsSinceEpoch + 1;
  } else {
    final day = ReportRange.containing(ReportPeriod.day, now);
    from = day.startUtcMs;
    to = day.endUtcMs;
  }
  final rides =
      await ref.read(rideHistoryRepositoryProvider).getBetween(from, to);
  return rides.fold<int>(0, (s, r) => s + r.totalPrice);
});

/// Pređena ruta vožnje za prikaz na mapi.
final rideRouteProvider = FutureProvider.autoDispose
    .family<List<(double, double)>, int>(
      (ref, rideId) => ref.read(rideHistoryRepositoryProvider).getRoute(rideId),
    );
