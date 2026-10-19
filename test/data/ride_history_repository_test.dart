import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';
import 'package:taksimetar_balkan/data/repositories/ride_history_repository_impl.dart';

void main() {
  late Database db;
  late RideHistoryRepositoryImpl repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await deleteDatabase(inMemoryDatabasePath);
    db = await DatabaseHelper.openAt(inMemoryDatabasePath);
    repo = RideHistoryRepositoryImpl(() async => db);
    addTearDown(() => db.close());
  });

  Future<void> ride(int start, String status,
      {int? end, int total = 300, int km = 50, int distance = 1500}) {
    return db.insert('rides', {
      'start_time': start,
      'end_time': end,
      'distance_m': distance,
      'waiting_time_sec': 30,
      'start_price': 200,
      'km_price': km,
      'waiting_price': 50,
      'total_price': total,
      'tariff_id': 1,
      'applied_calibration': 1.0,
      'status': status,
      'min_price_adjustment': 0,
    });
  }

  test('prazna baza → prazna istorija', () async {
    expect(await repo.getAll(), isEmpty);
  });

  test('najnovije prvo, vožnja u toku se ne prikazuje', () async {
    await ride(1000, 'completed', end: 61000, total: 300);
    await ride(3000, 'completed', end: 123000, total: 450);
    await ride(2000, 'interrupted', end: 2500, total: 280);
    await ride(4000, 'active');

    final all = await repo.getAll();
    expect(all.map((r) => r.totalPrice), [450, 280, 300]);
    expect(all.map((r) => r.status), ['completed', 'interrupted', 'completed']);
  });

  test('polja i trajanje se mapiraju (UTC)', () async {
    await ride(1000, 'completed', end: 61000, distance: 2340, km: 187);
    final r = (await repo.getAll()).single;
    expect(r.distanceMeters, 2340);
    expect(r.kmPrice, 187);
    expect(r.waitingSeconds, 30);
    expect(r.startTime.isUtc, true);
    expect(r.duration, const Duration(seconds: 60));
    expect(r.isInterrupted, false);
  });

  test('vožnja bez end_time nema trajanje', () async {
    await ride(1000, 'interrupted');
    final r = (await repo.getAll()).single;
    expect(r.endTime, isNull);
    expect(r.duration, isNull);
    expect(r.isInterrupted, true);
  });

  test('limit', () async {
    for (var i = 0; i < 5; i++) {
      await ride(1000 + i, 'completed', end: 2000 + i);
    }
    expect((await repo.getAll(limit: 3)).length, 3);
  });
}
