import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('taximetar_balkan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    return openAt(join(dbPath, filePath));
  }

  /// Otvara bazu na datoj putanji sa produkcijskom šemom i migracijama.
  /// Testovi ovim otvaraju `inMemoryDatabasePath` preko sqflite_ffi.
  static Future<Database> openAt(String path) {
    return openDatabase(
      path,
      version: 9,
      onConfigure: _configureDB,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  static Future<void> _configureDB(Database db) async {
    // Na Androidu PRAGMA koja vraća red mora kroz rawQuery.
    await db.rawQuery('PRAGMA journal_mode=WAL');
    await db.rawQuery('PRAGMA busy_timeout=5000');
    await db.execute('PRAGMA foreign_keys=ON');
  }

  /// Smene vozača (Faza 3).
  static Future<void> _createShiftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER
      )
    ''');
  }

  /// V12: prekidi GPS signala tokom vožnje i kako su obračunati.
  static Future<void> _createGapsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ride_gaps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        kind TEXT NOT NULL,
        added_distance_m INTEGER NOT NULL,
        added_waiting_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_gaps_ride ON ride_gaps(ride_id)');
  }

  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tariffs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_price INTEGER NOT NULL,
        price_per_km INTEGER NOT NULL,
        waiting_para_per_min INTEGER NOT NULL,
        min_price INTEGER NOT NULL,
        rules_json TEXT,
        schedule_days INTEGER NOT NULL DEFAULT 0,
        schedule_start_min INTEGER NOT NULL DEFAULT 0,
        schedule_end_min INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE holidays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date_string TEXT NOT NULL,
        multiplier REAL NOT NULL,
        recurring_yearly INTEGER NOT NULL,
        tariff_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE rides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        distance_m INTEGER NOT NULL,
        waiting_time_sec INTEGER NOT NULL,
        start_price INTEGER NOT NULL,
        km_price INTEGER NOT NULL,
        waiting_price INTEGER NOT NULL,
        total_price INTEGER NOT NULL,
        tariff_id INTEGER NOT NULL,
        applied_calibration REAL NOT NULL,
        status TEXT NOT NULL,
        tariff_start_price INTEGER DEFAULT 0,
        tariff_price_per_km INTEGER DEFAULT 0,
        tariff_waiting_para_per_min INTEGER DEFAULT 0,
        tariff_min_price INTEGER DEFAULT 0,
        min_price_adjustment INTEGER DEFAULT 0,
        client_uuid TEXT,
        waiting_speed_kmh INTEGER,
        gps_accuracy_m INTEGER
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_rides_client_uuid ON rides(client_uuid)');

    await db.execute('''
      CREATE TABLE ride_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id INTEGER NOT NULL,
        current_distance REAL NOT NULL,
        current_waiting_ms INTEGER NOT NULL,
        current_price INTEGER NOT NULL,
        last_lat REAL NOT NULL,
        last_lon REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        saved_at INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_snapshots_ride ON ride_snapshots(ride_id)');

    await _createGapsTable(db);
    await _createShiftsTable(db);

    await db.execute('''
      CREATE TABLE fixed_routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        from_label TEXT NOT NULL,
        to_label TEXT NOT NULL,
        conditions TEXT,
        fixed_price INTEGER NOT NULL
      )
    ''');

    await db.insert('app_settings', {'key': 'waiting_speed_threshold', 'value': '8.0'});
    await db.insert('app_settings', {'key': 'gps_accuracy_threshold', 'value': '15.0'});
    await db.insert('app_settings', {'key': 'calibration_multiplier', 'value': '1.0'});
  }

  static Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // N7: stare aktivne vožnje nemaju tarifu u rides (tariff_* = 0), pa se
      // ne mogu oporaviti; označavamo ih kao prekinute pre brisanja snapshot-a.
      await db.execute(
          "UPDATE rides SET status = 'interrupted', end_time = COALESCE(end_time, start_time) WHERE status = 'active'");
      // Dodajemo nove kolone u postojeću tabelu rides
      await db.execute('ALTER TABLE rides ADD COLUMN tariff_start_price INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE rides ADD COLUMN tariff_price_per_km INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE rides ADD COLUMN tariff_waiting_price_per_min INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE rides ADD COLUMN tariff_min_price INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE rides ADD COLUMN min_price_adjustment INTEGER DEFAULT 0');
      
      // Brišemo staru snapshot tabelu i pravimo novu sa pravilnim tipovima
      await db.execute('DROP TABLE IF EXISTS ride_snapshots');
      await db.execute('''
        CREATE TABLE ride_snapshots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ride_id INTEGER NOT NULL,
          current_distance REAL NOT NULL,
          current_waiting_ms INTEGER NOT NULL,
          current_price INTEGER NOT NULL,
          last_lat REAL NOT NULL,
          last_lon REAL NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE ride_snapshots ADD COLUMN saved_at INTEGER');
      await db.execute('ALTER TABLE rides ADD COLUMN client_uuid TEXT');
      await db.execute(
          'CREATE UNIQUE INDEX idx_rides_client_uuid ON rides(client_uuid)');
      await db.execute(
          'CREATE INDEX idx_snapshots_ride ON ride_snapshots(ride_id)');
    }
    if (oldVersion < 4) {
      // Čekanje se unosi sa decimalama (npr. 13.4 din/min), a novac je int:
      // cena čekanja po minutu se od sada čuva u para (1/100 dinara).
      await _waitingToPara(
          db, 'rides', 'tariff_waiting_price_per_min', 'tariff_waiting_para_per_min');
      await _waitingToPara(
          db, 'tariffs', 'waiting_price_per_min', 'waiting_para_per_min');
    }
    if (oldVersion < 9) {
      await _createShiftsTable(db);
    }
    if (oldVersion < 8) {
      // Faza 2: raspored tarife (dani + vreme od-do) i tarifa praznika.
      for (final col in ['schedule_days', 'schedule_start_min', 'schedule_end_min']) {
        await _addColumn(db, 'tariffs', col, 'INTEGER NOT NULL DEFAULT 0');
      }
      await _addColumn(db, 'holidays', 'tariff_id', 'INTEGER');
    }
    if (oldVersion < 7) {
      // Prag GPS tačnosti (m) koji je važio za vožnju; null = podrazumevani.
      await db.execute('ALTER TABLE rides ADD COLUMN gps_accuracy_m INTEGER');
    }
    if (oldVersion < 6) {
      await _createGapsTable(db);
    }
    if (oldVersion < 5) {
      // Prag brzine za čekanje (km/h) koji je važio za vožnju; null = podrazumevani.
      await db.execute('ALTER TABLE rides ADD COLUMN waiting_speed_kmh INTEGER');
    }
  }

  /// Dodaje kolonu ako tabela postoji, a kolona ne (nepotpune stare šeme).
  static Future<void> _addColumn(
      Database db, String table, String column, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.isEmpty || columns.any((c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  /// Preimenuje kolonu i množi vrednosti sa 100; preskače ako tabela ili
  /// kolona ne postoje (npr. nepotpuna stara šema).
  static Future<void> _waitingToPara(
      Database db, String table, String oldName, String newName) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((c) => c['name'] == oldName)) return;
    await db.execute('ALTER TABLE $table RENAME COLUMN $oldName TO $newName');
    await db.execute('UPDATE $table SET $newName = $newName * 100');
  }
}
