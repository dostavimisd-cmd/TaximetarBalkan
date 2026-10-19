import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';
import 'package:taksimetar_balkan/data/repositories/settings_repository_impl.dart';
import 'package:taksimetar_balkan/data/repositories/tariff_repository_impl.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

void main() {
  late Database db;
  late TariffRepositoryImpl repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await deleteDatabase(inMemoryDatabasePath);
    db = await DatabaseHelper.openAt(inMemoryDatabasePath);
    repo = TariffRepositoryImpl(() async => db);
    addTearDown(() => db.close());
  });

  const base = Tariff(
    id: 0,
    name: 'Dnevna',
    startPrice: 100,
    pricePerKm: 50,
    waitingPricePerMin: 10,
    minPrice: 200,
  );

  test('nova baza nema ugrađenih tarifa (Pravilo 3)', () async {
    expect(await repo.getAll(), isEmpty);
  });

  test('upis, čitanje, izmena i brisanje', () async {
    final id = await repo.save(base);
    expect(id, greaterThan(0));

    var all = await repo.getAll();
    expect(all.single.name, 'Dnevna');
    expect(all.single.pricePerKm, 50);

    await repo.save(base.copyWith(id: id, name: ' Noćna ', pricePerKm: 70));
    all = await repo.getAll();
    expect(all.length, 1);
    expect(all.single.name, 'Noćna'); // trim
    expect(all.single.pricePerKm, 70);

    await repo.delete(id);
    expect(await repo.getAll(), isEmpty);
  });

  test('nevalidna tarifa se ne upisuje', () async {
    expect(() => repo.save(base.copyWith(pricePerKm: -5)), throwsArgumentError);
    expect(await repo.getAll(), isEmpty);
  });

  test('brisanje tarife ne dira istoriju vožnji (kopija tarife u rides)', () async {
    final id = await repo.save(base);
    await db.insert('rides', {
      'start_time': 1, 'distance_m': 0, 'waiting_time_sec': 0,
      'start_price': 100, 'km_price': 0, 'waiting_price': 0, 'total_price': 200,
      'tariff_id': id, 'applied_calibration': 1.0, 'status': 'completed',
      'tariff_price_per_km': 50,
    });
    await repo.delete(id);
    final ride = (await db.query('rides')).single;
    expect(ride['tariff_price_per_km'], 50);
  });

  test('kurs se čuva kao podešavanje', () async {
    final settings = SettingsRepositoryImpl(_TestHelper(db));
    expect(await settings.getSetting('eur_rate_milli'), isNull);
    await settings.saveSetting('eur_rate_milli', '117200');
    await settings.saveSetting('eur_rate_milli', '118000'); // zamena
    expect(await settings.getSetting('eur_rate_milli'), '118000');
  });
}

class _TestHelper implements DatabaseHelper {
  _TestHelper(this._db);
  final Database _db;

  @override
  Future<Database> get database async => _db;
}
