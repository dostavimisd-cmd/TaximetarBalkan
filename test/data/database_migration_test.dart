import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:taksimetar_balkan/data/database_helper.dart';

Future<Set<String>> columns(Database db, String table) async =>
    (await db.rawQuery('PRAGMA table_info($table)'))
        .map((r) => r['name'] as String)
        .toSet();

Future<Set<String>> indexes(Database db) async =>
    (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'"))
        .map((r) => r['name'] as String)
        .toSet();

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('nova baza ima v4 šemu i indekse', () async {
    final db = await DatabaseHelper.openAt(inMemoryDatabasePath);
    addTearDown(db.close);
    expect(await columns(db, 'rides'), containsAll(['client_uuid', 'tariff_min_price']));
    expect(await columns(db, 'ride_snapshots'), contains('saved_at'));
    expect(await indexes(db),
        containsAll(['idx_rides_client_uuid', 'idx_snapshots_ride']));
    expect(await db.query('app_settings'), hasLength(3));
  });

  test('5: migracija v1 → v13 čuva istoriju i prekida aktivnu vožnju', () async {
    final dir = await Directory.systemTemp.createTemp('taksi_mig');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'v1.db');

    // v1 šema iz commita 4417b00
    final v1 = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute('''
                CREATE TABLE rides (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  start_time INTEGER NOT NULL, end_time INTEGER,
                  distance_m INTEGER NOT NULL, waiting_time_sec INTEGER NOT NULL,
                  start_price INTEGER NOT NULL, km_price INTEGER NOT NULL,
                  waiting_price INTEGER NOT NULL, total_price INTEGER NOT NULL,
                  tariff_id INTEGER NOT NULL, applied_calibration REAL NOT NULL,
                  status TEXT NOT NULL)''');
              await db.execute('''
                CREATE TABLE tariffs (
                  id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
                  start_price INTEGER NOT NULL, price_per_km INTEGER NOT NULL,
                  waiting_price_per_min INTEGER NOT NULL, min_price INTEGER NOT NULL,
                  rules_json TEXT)''');
              await db.execute('''
                CREATE TABLE ride_snapshots (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  ride_id INTEGER NOT NULL, current_distance INTEGER NOT NULL,
                  current_waiting_sec INTEGER NOT NULL, current_price INTEGER NOT NULL,
                  last_lat REAL, last_lon REAL, timestamp INTEGER NOT NULL)''');
            }));
    Map<String, Object?> ride(String status, int id) => {
          'id': id, 'start_time': 1000, 'distance_m': 500,
          'waiting_time_sec': 0, 'start_price': 200, 'km_price': 50,
          'waiting_price': 0, 'total_price': 250, 'tariff_id': 1,
          'applied_calibration': 1.0, 'status': status,
        };
    await v1.insert('rides', ride('completed', 1)..['end_time'] = 2000);
    await v1.insert('rides', ride('active', 2));
    await v1.insert('tariffs', {
      'name': 'Stara', 'start_price': 100, 'price_per_km': 50,
      'waiting_price_per_min': 15, 'min_price': 200,
    });
    await v1.close();

    final db = await DatabaseHelper.openAt(path);
    addTearDown(db.close);

    final rides = await db.query('rides', orderBy: 'id');
    expect(rides[0]['status'], 'completed');
    expect(rides[0]['total_price'], 250);
    expect(rides[1]['status'], 'interrupted');
    expect(rides[1]['end_time'], 1000);
    expect(await columns(db, 'rides'),
        containsAll(['tariff_start_price', 'min_price_adjustment', 'client_uuid']));
    expect(await columns(db, 'ride_snapshots'),
        containsAll(['current_waiting_ms', 'saved_at']));

    // v4: čekanje po minutu je u para (15 din → 1500)
    expect(await columns(db, 'tariffs'), contains('waiting_para_per_min'));
    expect((await db.query('tariffs')).single['waiting_para_per_min'], 1500);
    expect(await columns(db, 'rides'), contains('tariff_waiting_para_per_min'));
    // v13: troškovi smene
    expect(await columns(db, 'shift_expenses'), containsAll(['shift_id', 'name', 'amount', 'created_at']));
    expect(await indexes(db), contains('idx_expenses_shift'));
    // v12: prvi km u tarifi, doplate u vožnji
    expect(await columns(db, 'tariffs'), contains('first_km_price'));
    expect((await db.query('tariffs')).single['first_km_price'], isNull);
    expect(await columns(db, 'rides'), containsAll(['tariff_first_km_price', 'extras_total']));
    expect(await columns(db, 'ride_extras'), containsAll(['ride_id', 'name', 'amount', 'added_at']));
    expect(await indexes(db), contains('idx_extras_ride'));
    // v11: pauza i tačke rute
    expect(await columns(db, 'rides'), contains('paused_sec'));
    expect(await columns(db, 'ride_points'), containsAll(['ride_id', 'ts', 'lat', 'lon']));
    // v10: fiksna relacija po vožnji
    expect(await columns(db, 'rides'), containsAll(['fixed_price', 'fixed_route_name']));
    // v9: smene
    expect(await columns(db, 'shifts'), containsAll(['start_time', 'end_time']));
    // v8: raspored tarife i tarifa praznika
    expect(await columns(db, 'tariffs'), containsAll(['schedule_days', 'schedule_start_min', 'schedule_end_min']));
    // v7: prag GPS tačnosti po vožnji
    expect(await columns(db, 'rides'), contains('gps_accuracy_m'));
    // v6: tabela prekida signala
    expect(await columns(db, 'ride_gaps'), containsAll(['ride_id', 'kind', 'duration_ms']));
    expect(await indexes(db), contains('idx_gaps_ride'));
    // v5: prag brzine za čekanje po vožnji
    expect(await columns(db, 'rides'), contains('waiting_speed_kmh'));
    expect(await indexes(db),
        containsAll(['idx_rides_client_uuid', 'idx_snapshots_ride']));
  });
}
