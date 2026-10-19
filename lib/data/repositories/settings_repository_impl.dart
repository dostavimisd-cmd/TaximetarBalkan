import '../../domain/repositories/settings_repository.dart';
import '../database_helper.dart';
import 'package:sqflite/sqflite.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final DatabaseHelper _dbHelper;

  SettingsRepositoryImpl(this._dbHelper);

  @override
  Future<void> saveSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  @override
  Future<Map<String, String>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query('app_settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  @override
  Future<void> saveAll(Map<String, String> values) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final e in values.entries) {
        await txn.insert('app_settings', {'key': e.key, 'value': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}