import '../../domain/repositories/ride_repository.dart';
import '../database_helper.dart';

class RideRepositoryImpl implements RideRepository {
  final DatabaseHelper _dbHelper;

  RideRepositoryImpl(this._dbHelper);

  @override
  Future<int> startRide(Map<String, dynamic> rideData) async {
    final db = await _dbHelper.database;
    return await db.insert('rides', rideData);
  }

  @override
  Future<void> updateSnapshot(Map<String, dynamic> snapshotData) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('ride_snapshots');
      await txn.insert('ride_snapshots', snapshotData);
    });
  }

  @override
  Future<Map<String, dynamic>?> getUnfinishedRideSnapshot() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'ride_snapshots',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  @override
  Future<void> finishRide(int rideId, Map<String, dynamic> finalData) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'rides',
        finalData,
        where: 'id = ?',
        whereArgs: [rideId],
      );
      await txn.delete('ride_snapshots');
    });
  }
}