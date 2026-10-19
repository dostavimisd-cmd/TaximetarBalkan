import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';
import 'package:taksimetar_balkan/data/repositories/fixed_route_repository_impl.dart';
import 'package:taksimetar_balkan/domain/models/fixed_route.dart';

void main() {
  late Database db;
  late FixedRouteRepositoryImpl repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await deleteDatabase(inMemoryDatabasePath);
    db = await DatabaseHelper.openAt(inMemoryDatabasePath);
    repo = FixedRouteRepositoryImpl(() async => db);
    addTearDown(() => db.close());
  });

  test('nema ugrađenih relacija; upis, izmena, brisanje', () async {
    expect(await repo.getAll(), isEmpty);
    final id = await repo.save(const FixedRoute(
        name: 'Aerodrom', fromLabel: 'Centar', toLabel: 'Aerodrom', price: 2500));
    var all = await repo.getAll();
    expect(all.single.describe(), 'Centar → Aerodrom · 2500 din');

    await repo.save(FixedRoute(id: id, name: 'Aerodrom', price: 2700));
    all = await repo.getAll();
    expect(all.single.price, 2700);
    expect(all.single.describe(), '2700 din');

    await repo.delete(id);
    expect(await repo.getAll(), isEmpty);
  });

  test('nevalidna relacija se ne upisuje', () async {
    expect(() => repo.save(const FixedRoute(name: ' ', price: 100)), throwsArgumentError);
    expect(() => repo.save(const FixedRoute(name: 'x', price: 0)), throwsArgumentError);
  });

  test('importAll: nove relacije, a postojeća (isto ime/od/do) menja cenu', () async {
    await repo.save(const FixedRoute(name: 'Aerodrom', fromLabel: 'Centar', toLabel: 'Surčin', price: 2500));
    final r = await repo.importAll(const [
      FixedRoute(name: 'aerodrom', fromLabel: 'centar', toLabel: 'surčin', price: 2800),
      FixedRoute(name: 'Novi Sad', price: 4500),
      FixedRoute(name: 'Novi Sad', fromLabel: 'Centar', price: 4700),
    ]);
    expect(r.added, 2);
    expect(r.updated, 1);
    final all = await repo.getAll();
    expect(all.length, 3);
    expect(all.firstWhere((x) => x.name.toLowerCase() == 'aerodrom').price, 2800);
  });

  test('importAll: nevalidna relacija poništava ceo uvoz', () async {
    expect(
      () => repo.importAll(const [
        FixedRoute(name: 'Dobra', price: 100),
        FixedRoute(name: 'Loša', price: 0),
      ]),
      throwsArgumentError,
    );
    expect(await repo.getAll(), isEmpty);
  });
}
