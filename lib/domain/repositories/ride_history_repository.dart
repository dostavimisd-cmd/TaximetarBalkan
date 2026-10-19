import '../models/gap_info.dart';
import '../models/ride_record.dart';

abstract class RideHistoryRepository {
  /// Završene i prekinute vožnje, najnovije prvo. Vožnja u toku se ne vraća.
  Future<List<RideRecord>> getAll({int limit = 200});

  /// Završene i prekinute vožnje koje su počele u [fromUtcMs, toUtcMs).
  Future<List<RideRecord>> getBetween(int fromUtcMs, int toUtcMs);

  Future<RideRecord?> getById(int id);

  /// Prekidi GPS signala u vožnji, po redu nastanka.
  Future<List<GapInfo>> getGaps(int rideId);
}
