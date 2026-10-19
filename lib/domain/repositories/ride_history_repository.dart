import '../models/gap_info.dart';
import '../models/ride_record.dart';

abstract class RideHistoryRepository {
  /// Završene i prekinute vožnje, najnovije prvo. Vožnja u toku se ne vraća.
  Future<List<RideRecord>> getAll({int limit = 200});

  /// Prekidi GPS signala u vožnji, po redu nastanka.
  Future<List<GapInfo>> getGaps(int rideId);
}
