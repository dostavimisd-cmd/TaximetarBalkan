import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database_helper.dart';
import '../../data/repositories/ride_history_repository_impl.dart';
import '../../data/repositories/shift_repository_impl.dart';
import '../../domain/models/shift.dart';
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
