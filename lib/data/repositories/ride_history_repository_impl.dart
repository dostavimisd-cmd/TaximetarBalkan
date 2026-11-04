import 'package:sqflite/sqflite.dart';
import '../../domain/models/extra_charge.dart';
import '../../domain/models/gap_info.dart';
import '../../domain/models/ride_record.dart';
import '../../domain/repositories/ride_history_repository.dart';

/// Čita istoriju i briše završene vožnje na zahtev korisnika. Vožnje u toku
/// menja samo servis (RideEngine); brisanje njih ne dira.
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

  @override
  Future<RideRecord?> getById(int id) async {
    final db = await _database();
    final rows = await db.query('rides', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final extras = await db.query('ride_extras',
        where: 'ride_id = ?', whereArgs: [id], orderBy: 'id');
    return _fromRow(rows.first, extras: [
      for (final e in extras)
        ExtraCharge(
          id: e['id'] as int,
          name: e['name'] as String,
          amount: e['amount'] as int,
        ),
    ]);
  }

  @override
  Future<List<(double lat, double lon)>> getRoute(int rideId) async {
    final db = await _database();
    final rows = await db.query('ride_points',
        where: 'ride_id = ?', whereArgs: [rideId], orderBy: 'ts, id');
    return [
      for (final r in rows) ((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()),
    ];
  }

  @override
  Future<bool> delete(int id) async {
    final db = await _database();
    return db.transaction((txn) async {
      final n = await txn.delete('rides',
          where: "id = ? AND status != 'active'", whereArgs: [id]);
      if (n == 0) return false;
      await txn.delete('ride_gaps', where: 'ride_id = ?', whereArgs: [id]);
      await txn.delete('ride_snapshots', where: 'ride_id = ?', whereArgs: [id]);
      await txn.delete('ride_points', where: 'ride_id = ?', whereArgs: [id]);
      await txn.delete('ride_extras', where: 'ride_id = ?', whereArgs: [id]);
      return true;
    });
  }

  @override
  Future<List<RideRecord>> getBetween(int fromUtcMs, int toUtcMs) async {
    final db = await _database();
    final rows = await db.query(
      'rides',
      where: "status != 'active' AND start_time >= ? AND start_time < ?",
      whereArgs: [fromUtcMs, toUtcMs],
      orderBy: 'start_time, id',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<GapInfo>> getGaps(int rideId) async {
    final db = await _database();
    final rows = await db.query('ride_gaps',
        where: 'ride_id = ?', whereArgs: [rideId], orderBy: 'started_at, id');
    return rows
        .map((r) => GapInfo(
              startedAt: DateTime.fromMillisecondsSinceEpoch(
                  r['started_at'] as int,
                  isUtc: true),
              durationMs: r['duration_ms'] as int,
              kind: r['kind'] as String,
              addedDistanceMeters: r['added_distance_m'] as int,
              addedWaitingMs: r['added_waiting_ms'] as int,
            ))
        .toList();
  }

  RideRecord _fromRow(Map<String, Object?> r, {List<ExtraCharge> extras = const []}) {
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
      extrasTotal: (r['extras_total'] as int?) ?? 0,
      extras: extras,
      totalPrice: r['total_price'] as int,
      status: r['status'] as String,
      fixedRouteName: r['fixed_route_name'] as String?,
      pausedSeconds: (r['paused_sec'] as int?) ?? 0,
    );
  }
}
