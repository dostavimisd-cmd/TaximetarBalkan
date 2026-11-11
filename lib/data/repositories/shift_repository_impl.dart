import 'package:sqflite/sqflite.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/shift_expense.dart';
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
  Future<List<ShiftExpense>> getExpenses(int shiftId) async {
    final db = await _database();
    final rows = await db.query('shift_expenses',
        where: 'shift_id = ?', whereArgs: [shiftId], orderBy: 'id');
    return rows.map(_expenseFromRow).toList();
  }

  @override
  Future<List<ShiftExpense>> getExpensesBetween(int fromUtcMs, int toUtcMs) async {
    final db = await _database();
    final rows = await db.query('shift_expenses',
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [fromUtcMs, toUtcMs],
        orderBy: 'created_at');
    return rows.map(_expenseFromRow).toList();
  }

  ShiftExpense _expenseFromRow(Map<String, Object?> r) => ShiftExpense(
        id: r['id'] as int,
        shiftId: r['shift_id'] as int,
        name: r['name'] as String,
        amount: r['amount'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int, isUtc: true),
      );

  @override
  Future<int> addExpense(ShiftExpense expense, DateTime nowUtc) async {
    final error = expense.validate();
    if (error != null) throw ArgumentError(error);
    final db = await _database();
    return db.insert('shift_expenses', {
      'shift_id': expense.shiftId,
      'name': expense.name.trim(),
      'amount': expense.amount,
      'created_at': nowUtc.toUtc().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> deleteExpense(int id) async {
    final db = await _database();
    await db.delete('shift_expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> end(DateTime nowUtc) async {
    final db = await _database();
    await db.update('shifts', {'end_time': nowUtc.toUtc().millisecondsSinceEpoch},
        where: 'end_time IS NULL');
  }
}
