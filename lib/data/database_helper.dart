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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
        waiting_price_per_min INTEGER NOT NULL,
        min_price INTEGER NOT NULL,
        rules_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE holidays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date_string TEXT NOT NULL,
        multiplier REAL NOT NULL,
        recurring_yearly INTEGER NOT NULL
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
        tariff_waiting_price_per_min INTEGER DEFAULT 0,
        tariff_min_price INTEGER DEFAULT 0,
        min_price_adjustment INTEGER DEFAULT 0
      )
    ''');

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
  }
}