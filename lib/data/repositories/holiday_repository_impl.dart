import 'package:sqflite/sqflite.dart';
import '../../domain/models/holiday.dart';
import '../../domain/repositories/holiday_repository.dart';

class HolidayRepositoryImpl implements HolidayRepository {
  HolidayRepositoryImpl(this._database);

  final Future<Database> Function() _database;

  @override
  Future<List<Holiday>> getAll() async {
    final db = await _database();
    // Redovi bez tarife (stara šema) ili sa neispravnim datumom se preskaču.
    final rows = await db.query('holidays',
        where: 'tariff_id IS NOT NULL', orderBy: 'date_string, id');
    final result = <Holiday>[];
    for (final r in rows) {
      final date = Holiday.parseDateString(r['date_string'] as String);
      if (date == null) continue;
      result.add(Holiday(
        id: r['id'] as int,
        name: r['name'] as String,
        month: date.month,
        day: date.day,
        year: date.year,
        tariffId: r['tariff_id'] as int,
      ));
    }
    return result;
  }

  @override
  Future<int> save(Holiday holiday) async {
    final error = holiday.validate();
    if (error != null) throw ArgumentError(error);
    final db = await _database();
    final values = {
      'name': holiday.name.trim(),
      'date_string': holiday.dateString,
      'multiplier': 1.0, // kolona iz v1 šeme, ne koristi se
      'recurring_yearly': holiday.recurring ? 1 : 0,
      'tariff_id': holiday.tariffId,
    };
    if (holiday.id == 0) return db.insert('holidays', values);
    await db.update('holidays', values, where: 'id = ?', whereArgs: [holiday.id]);
    return holiday.id;
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database();
    await db.delete('holidays', where: 'id = ?', whereArgs: [id]);
  }
}
