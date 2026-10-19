import 'package:sqflite/sqflite.dart';
import '../../domain/models/fixed_route.dart';
import '../../domain/repositories/fixed_route_repository.dart';

class FixedRouteRepositoryImpl implements FixedRouteRepository {
  FixedRouteRepositoryImpl(this._database);

  final Future<Database> Function() _database;

  @override
  Future<List<FixedRoute>> getAll() async {
    final db = await _database();
    final rows = await db.query('fixed_routes', orderBy: 'name, id');
    return [
      for (final r in rows)
        FixedRoute(
          id: r['id'] as int,
          name: r['name'] as String,
          fromLabel: r['from_label'] as String,
          toLabel: r['to_label'] as String,
          price: r['fixed_price'] as int,
        ),
    ];
  }

  @override
  Future<int> save(FixedRoute route) async {
    final error = route.validate();
    if (error != null) throw ArgumentError(error);
    final db = await _database();
    final values = {
      'name': route.name.trim(),
      'from_label': route.fromLabel.trim(),
      'to_label': route.toLabel.trim(),
      'fixed_price': route.price,
    };
    if (route.id == 0) return db.insert('fixed_routes', values);
    await db.update('fixed_routes', values, where: 'id = ?', whereArgs: [route.id]);
    return route.id;
  }

  @override
  Future<({int added, int updated})> importAll(List<FixedRoute> routes) async {
    for (final r in routes) {
      final error = r.validate();
      if (error != null) throw ArgumentError('${r.name}: $error');
    }
    final db = await _database();
    var added = 0, updated = 0;
    await db.transaction((txn) async {
      final existing = await txn.query('fixed_routes');
      String key(String n, String f, String t) =>
          '${n.trim().toLowerCase()}|${f.trim().toLowerCase()}|${t.trim().toLowerCase()}';
      final byKey = {
        for (final e in existing)
          key(e['name'] as String, e['from_label'] as String, e['to_label'] as String):
              e['id'] as int,
      };
      for (final r in routes) {
        final values = {
          'name': r.name.trim(),
          'from_label': r.fromLabel.trim(),
          'to_label': r.toLabel.trim(),
          'fixed_price': r.price,
        };
        final k = key(r.name, r.fromLabel, r.toLabel);
        final id = byKey[k];
        if (id == null) {
          byKey[k] = await txn.insert('fixed_routes', values);
          added++;
        } else {
          await txn.update('fixed_routes', values, where: 'id = ?', whereArgs: [id]);
          updated++;
        }
      }
    });
    return (added: added, updated: updated);
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database();
    // Vožnje čuvaju naziv i cenu relacije (rides.fixed_*), pa istorija ostaje.
    await db.delete('fixed_routes', where: 'id = ?', whereArgs: [id]);
  }
}
