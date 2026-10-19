import 'package:sqflite/sqflite.dart';
import '../../domain/models/ride_record.dart';
import '../../domain/repositories/ride_history_repository.dart';

/// Samo čita. Jedini pisac u `rides` je servis (RideEngine).
class RideHistoryRepositoryImpl implements RideHistoryRepository {
  RideHistoryRepositoryImpl(this._database);

  final Future<Database> Function() _database;

  @override
  Future<List<RideRecord>> getAll({int limit = 200}) async {
    final db = await _database();
    final rows = await db.query(
      'rides',
      where: "status != 'active'",
      orderBy: 'start_time DESC, id DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  RideRecord _fromRow(Map<String, Object?> r) {
    DateTime utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final end = r['end_time'] as int?;
    return RideRecord(
      id: r['id'] as int,
      startTime: utc(r['start_time'] as int),
      endTime: end == null ? null : utc(end),
      distanceMeters: r['distance_m'] as int,
      waitingSeconds: r['waiting_time_sec'] as int,
      startPrice: r['start_price'] as int,
      kmPrice: r['km_price'] as int,
      waitingPrice: r['waiting_price'] as int,
      minPriceAdjustment: (r['min_price_adjustment'] as int?) ?? 0,
      totalPrice: r['total_price'] as int,
      status: r['status'] as String,
    );
  }
}
