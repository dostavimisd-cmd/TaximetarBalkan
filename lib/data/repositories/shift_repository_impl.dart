import 'package:sqflite/sqflite.dart';
import '../../domain/models/shift.dart';
import '../../domain/repositories/shift_repository.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  ShiftRepositoryImpl(this._database);

  final Future<Database> Function() _database;

  Shift _fromRow(Map<String, Object?> r) {
    DateTime utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final end = r['end_time'] as int?;
    return Shift(
      id: r['id'] as int,
      start: utc(r['start_time'] as int),
      end: end == null ? null : utc(end),
    );
  }

  @override
  Future<List<Shift>> getAll() async {
    final db = await _database();
    final rows = await db.query('shifts', orderBy: 'start_time DESC, id DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Shift?> current() async {
    final db = await _database();
    final rows = await db.query('shifts',
        where: 'end_time IS NULL', orderBy: 'start_time DESC', limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<Shift> start(DateTime nowUtc) async {
    final open = await current();
    if (open != null) return open;
    final db = await _database();
    final ms = nowUtc.toUtc().millisecondsSinceEpoch;
    final id = await db.insert('shifts', {'start_time': ms, 'end_time': null});
    return Shift(id: id, start: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
  }

  @override
  Future<void> end(DateTime nowUtc) async {
    final db = await _database();
    await db.update('shifts', {'end_time': nowUtc.toUtc().millisecondsSinceEpoch},
        where: 'end_time IS NULL');
  }
}
