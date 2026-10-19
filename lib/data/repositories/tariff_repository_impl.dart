import 'package:sqflite/sqflite.dart';
import '../../domain/models/tariff.dart';
import '../../domain/repositories/tariff_repository.dart';

class TariffRepositoryImpl implements TariffRepository {
  TariffRepositoryImpl(this._database);

  final Future<Database> Function() _database;

  @override
  Future<List<Tariff>> getAll() async {
    final db = await _database();
    final rows = await db.query('tariffs', orderBy: 'id');
    return rows
        .map((r) => Tariff(
              id: r['id'] as int,
              name: r['name'] as String,
              startPrice: r['start_price'] as int,
              pricePerKm: r['price_per_km'] as int,
              waitingPricePerMin: r['waiting_price_per_min'] as int,
              minPrice: r['min_price'] as int,
            ))
        .toList();
  }

  @override
  Future<int> save(Tariff tariff) async {
    final error = tariff.validate();
    if (error != null) throw ArgumentError(error);

    final db = await _database();
    final values = {
      'name': tariff.name.trim(),
      'start_price': tariff.startPrice,
      'price_per_km': tariff.pricePerKm,
      'waiting_price_per_min': tariff.waitingPricePerMin,
      'min_price': tariff.minPrice,
    };
    if (tariff.id == 0) return db.insert('tariffs', values);
    await db.update('tariffs', values, where: 'id = ?', whereArgs: [tariff.id]);
    return tariff.id;
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database();
    // Vožnje čuvaju sopstvenu kopiju tarife (rides.tariff_*), pa brisanje
    // ne menja istoriju.
    await db.delete('tariffs', where: 'id = ?', whereArgs: [id]);
  }
}
