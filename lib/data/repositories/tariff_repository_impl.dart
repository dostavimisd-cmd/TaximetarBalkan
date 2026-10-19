import 'package:sqflite/sqflite.dart';
import '../../domain/models/tariff.dart';
import '../../domain/models/tariff_schedule.dart';
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
              waitingParaPerMin: r['waiting_para_per_min'] as int,
              minPrice: r['min_price'] as int,
              schedule: (r['schedule_days'] as int? ?? 0) == 0
                  ? null
                  : TariffSchedule(
                      days: r['schedule_days'] as int,
                      startMinute: r['schedule_start_min'] as int,
                      endMinute: r['schedule_end_min'] as int,
                    ),
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
      'waiting_para_per_min': tariff.waitingParaPerMin,
      'min_price': tariff.minPrice,
      'schedule_days': tariff.schedule?.days ?? 0,
      'schedule_start_min': tariff.schedule?.startMinute ?? 0,
      'schedule_end_min': tariff.schedule?.endMinute ?? 0,
    };
    if (tariff.id == 0) return db.insert('tariffs', values);
    await db.update('tariffs', values, where: 'id = ?', whereArgs: [tariff.id]);
    return tariff.id;
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database();
    // Vožnje čuvaju sopstvenu kopiju tarife (rides.tariff_*), pa brisanje
    // ne menja istoriju. Praznici vezani za tarifu se brišu sa njom.
    await db.transaction((txn) async {
      await txn.delete('holidays', where: 'tariff_id = ?', whereArgs: [id]);
      await txn.delete('tariffs', where: 'id = ?', whereArgs: [id]);
    });
  }
}
