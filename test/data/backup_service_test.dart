import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';
import 'package:taksimetar_balkan/data/services/backup_service.dart';

/// Popunjava bazu podacima vozača (svaka tabela iz kopije ima bar jedan red).
Future<void> seed(Database db, {String? logoPath}) async {
  await db.insert('app_settings', {'key': 'language', 'value': 'en'});
  if (logoPath != null) {
    await db.insert('app_settings', {'key': 'receipt_logo', 'value': logoPath});
  }
  final tariff = await db.insert('tariffs', {
    'name': 'Dan', 'start_price': 250, 'price_per_km': 80,
    'waiting_para_per_min': 1340, 'min_price': 400,
  });
  await db.insert('holidays', {
    'name': 'Nova godina', 'date_string': '01-01', 'multiplier': 1.0,
    'recurring_yearly': 1, 'tariff_id': tariff,
  });
  await db.insert('fixed_routes', {
    'name': 'Aerodrom', 'from_label': 'Centar', 'to_label': 'Aerodrom', 'fixed_price': 2500,
  });
  final ride = await db.insert('rides', {
    'start_time': 1000, 'end_time': 61000, 'distance_m': 2520, 'waiting_time_sec': 30,
    'start_price': 250, 'km_price': 202, 'waiting_price': 7, 'total_price': 459,
    'tariff_id': tariff, 'applied_calibration': 1.025, 'status': 'completed',
  });
  await db.insert('ride_gaps', {
    'ride_id': ride, 'started_at': 5000, 'duration_ms': 12000, 'kind': 'waiting',
    'added_distance_m': 0, 'added_waiting_ms': 12000,
  });
  await db.insert('ride_points', {'ride_id': ride, 'ts': 2000, 'lat': 44.66, 'lon': 20.93});
  await db.insert('shifts', {'start_time': 500, 'end_time': 90000});
}

Future<Map<String, List<Map<String, Object?>>>> dump(Database db) async => {
      for (final t in BackupService.tables) t: await db.query(t, orderBy: 'id'),
    };

void main() {
  late Directory tmp;
  late Database source;
  late Database target;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('backup_test');
    source = await DatabaseHelper.openAt(p.join(tmp.path, 'source.db'));
    target = await DatabaseHelper.openAt(p.join(tmp.path, 'target.db'));
    addTearDown(() async {
      await source.close();
      await target.close();
      await tmp.delete(recursive: true);
    });
  });

  Future<Map<String, dynamic>> roundTrip(Map<String, dynamic> backup) async =>
      BackupService.decode(BackupService.encode(backup));

  test('izvoz pa uvoz na drugi telefon vraća iste podatke', () async {
    await seed(source);
    final backup = await roundTrip(await BackupService.export(source));
    await BackupService.restore(target, backup, filesDir: tmp.path);

    final before = await dump(source);
    final after = await dump(target);
    for (final t in BackupService.tables) {
      expect(after[t], before[t], reason: t);
    }
  });

  test('uvoz zamenjuje postojeće podatke (ne spaja)', () async {
    await seed(source);
    await target.insert('fixed_routes', {
      'name': 'Stara', 'from_label': '', 'to_label': '', 'fixed_price': 1,
    });
    final backup = await roundTrip(await BackupService.export(source));
    await BackupService.restore(target, backup, filesDir: tmp.path);

    final routes = await target.query('fixed_routes');
    expect(routes.map((r) => r['name']), ['Aerodrom']);
  });

  test('logo ide u kopiju i vraća se kao nov fajl sa novom putanjom', () async {
    final logo = File(p.join(tmp.path, 'logo.png'))..writeAsBytesSync([1, 2, 3, 4]);
    await seed(source, logoPath: logo.path);
    final backup = await roundTrip(await BackupService.export(source));

    final newDir = await Directory(p.join(tmp.path, 'novi_telefon')).create();
    await BackupService.restore(target, backup, filesDir: newDir.path);

    final row = (await target.query('app_settings',
            where: 'key = ?', whereArgs: ['receipt_logo']))
        .single;
    final restored = File(row['value'] as String);
    expect(p.dirname(restored.path), newDir.path);
    expect(restored.readAsBytesSync(), [1, 2, 3, 4]);
  });

  test('logo kog više nema: putanja se briše, ostalo se vraća', () async {
    await seed(source, logoPath: p.join(tmp.path, 'nepostoji.png'));
    final backup = await roundTrip(await BackupService.export(source));
    await BackupService.restore(target, backup, filesDir: tmp.path);

    final row = (await target.query('app_settings',
            where: 'key = ?', whereArgs: ['receipt_logo']))
        .single;
    expect(row['value'], '');
    expect(await target.query('tariffs'), hasLength(1));
  });

  test('kopija iz novije verzije aplikacije se odbija, baza se ne menja', () async {
    await seed(source);
    await seed(target);
    final backup = await roundTrip(await BackupService.export(source));
    backup['schema'] = (await target.getVersion()) + 1;
    final before = await dump(target);

    await expectLater(
      BackupService.restore(target, backup, filesDir: tmp.path),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before);
  });

  test('kolona koje nema u bazi se preskače (kopija drugačije šeme)', () async {
    await seed(source);
    final backup = await roundTrip(await BackupService.export(source));
    (backup['tables']['tariffs'] as List).first['kolona_iz_buducnosti'] = 7;
    await BackupService.restore(target, backup, filesDir: tmp.path);
    expect((await target.query('tariffs')).single['name'], 'Dan');
  });

  test('oštećena kopija: ništa se ne menja', () async {
    await seed(target);
    final before = await dump(target);

    expect(() => BackupService.decode('nije json'), throwsA(isA<BackupException>()));
    expect(() => BackupService.decode('{"app":"druga"}'), throwsA(isA<BackupException>()));

    final broken = await roundTrip(await BackupService.export(source));
    (broken['tables'] as Map).remove('rides');
    await expectLater(
      BackupService.restore(target, broken, filesDir: tmp.path),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before);
  });

  test('greška usred upisa vraća bazu u prethodno stanje (transakcija)', () async {
    await seed(source);
    await seed(target);
    final before = await dump(target);
    final backup = await roundTrip(await BackupService.export(source));
    // red bez obaveznog polja (NOT NULL) puca tek pri upisu, posle brisanja
    (backup['tables']['shifts'] as List).add({'end_time': 1});

    await expectLater(
      BackupService.restore(target, backup, filesDir: tmp.path),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before);
  });

  test('vožnja u toku blokira uvoz', () async {
    await seed(source);
    await target.insert('rides', {
      'start_time': 1, 'distance_m': 0, 'waiting_time_sec': 0, 'start_price': 0,
      'km_price': 0, 'waiting_price': 0, 'total_price': 0, 'tariff_id': 1,
      'applied_calibration': 1.0, 'status': 'active',
    });
    final backup = await roundTrip(await BackupService.export(source));
    await expectLater(
      BackupService.restore(target, backup, filesDir: tmp.path),
      throwsA(isA<BackupException>()),
    );
    expect((await target.query('rides')).single['status'], 'active');
  });
}
