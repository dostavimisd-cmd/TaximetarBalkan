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
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ride_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id INTEGER NOT NULL,
        current_distance INTEGER NOT NULL,
        current_waiting_sec INTEGER NOT NULL,
        current_price INTEGER NOT NULL,
        last_lat REAL,
        last_lon REAL,
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

    // Podrazumevane vrednosti
    await db.insert('app_settings', {'key': 'waiting_speed_threshold', 'value': '8.0'});
    await db.insert('app_settings', {'key': 'gps_accuracy_threshold', 'value': '15.0'});
    await db.insert('app_settings', {'key': 'calibration_multiplier', 'value': '1.0'});
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Migracije za buduće verzije
  }
}