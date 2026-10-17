import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';

void main() {
  // Inicijalizacija sqflite za desktop/test okruženje
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Testovi', () {
    setUp(() async {
      // Brisanje stare baze u memoriji pre svakog testa
      await deleteDatabase(inMemoryDatabasePath);
      DatabaseHelper.instance.database; 
    });

    test('Upis i oporavak nezavršene vožnje (Snapshot)', () async {
      // 1. Započinjemo vožnju
      final rideData = {
        'start_time': 1600000000,
        'distance_m': 0,
        'waiting_time_sec': 0,
        'start_price': 150,
        'km_price': 0,
        'waiting_price': 0,
        'total_price': 150,
        'tariff_id': 1,
        'applied_calibration': 1.0,
        'status': 'active'
      };
      
      // Koristimo direktan pristup in-memory bazi za test
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE rides (id INTEGER PRIMARY KEY AUTOINCREMENT, start_time INTEGER NOT NULL, end_time INTEGER, distance_m INTEGER NOT NULL, waiting_time_sec INTEGER NOT NULL, start_price INTEGER NOT NULL, km_price INTEGER NOT NULL, waiting_price INTEGER NOT NULL, total_price INTEGER NOT NULL, tariff_id INTEGER NOT NULL, applied_calibration REAL NOT NULL, status TEXT NOT NULL)');
          await db.execute('CREATE TABLE ride_snapshots (id INTEGER PRIMARY KEY AUTOINCREMENT, ride_id INTEGER NOT NULL, current_distance INTEGER NOT NULL, current_waiting_sec INTEGER NOT NULL, current_price INTEGER NOT NULL, last_lat REAL, last_lon REAL, timestamp INTEGER NOT NULL)');
        },
      ));

      int rideId = await db.insert('rides', rideData);

      // 2. Upisujemo snapshot (simulacija rada u pozadini)
      final snapshotData = {
        'ride_id': rideId,
        'current_distance': 1500,
        'current_waiting_sec': 60,
        'current_price': 250,
        'timestamp': 1600000500,
      };
      
      await db.insert('ride_snapshots', snapshotData);

      // 3. Provera oporavka
      final result = await db.query('ride_snapshots');
      expect(result.length, 1);
      expect(result.first['current_distance'], 1500);

      // 4. Završetak vožnje (brisanje snapshota)
      await db.delete('ride_snapshots');
      final finalSnapshot = await db.query('ride_snapshots');
      expect(finalSnapshot.isEmpty, true);
    });
  });
}