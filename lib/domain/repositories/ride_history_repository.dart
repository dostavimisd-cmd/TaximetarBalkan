import '../heatmap.dart';
import '../models/gap_info.dart';
import '../models/ride_record.dart';

abstract class RideHistoryRepository {
  /// Završene i prekinute vožnje, najnovije prvo. Vožnja u toku se ne vraća.
  Future<List<RideRecord>> getAll({int limit = 200});

  /// Završene i prekinute vožnje koje su počele u [fromUtcMs, toUtcMs).
  Future<List<RideRecord>> getBetween(int fromUtcMs, int toUtcMs);

  Future<RideRecord?> getById(int id);

  /// Tačke pređene rute (lat, lon) po redu vremena.
  Future<List<(double lat, double lon)>> getRoute(int rideId);

  /// Briše završenu ili prekinutu vožnju sa njenim prekidima signala.
  /// Vožnja u toku se ne briše (vraća false).
  Future<bool> delete(int id);

  /// Mesto (prva tačka rute) i vreme početka završenih vožnji, za toplotnu mapu.
  Future<List<RideStart>> getRideStarts();

  /// Prekidi GPS signala u vožnji, po redu nastanka.
  Future<List<GapInfo>> getGaps(int rideId);
}
