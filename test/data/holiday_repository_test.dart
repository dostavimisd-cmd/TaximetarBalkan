import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';
import 'package:taksimetar_balkan/data/repositories/holiday_repository_impl.dart';
import 'package:taksimetar_balkan/data/repositories/tariff_repository_impl.dart';
import 'package:taksimetar_balkan/domain/models/holiday.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';
import 'package:taksimetar_balkan/domain/models/tariff_schedule.dart';

void main() {
  late Database db;
  late HolidayRepositoryImpl holidays;
  late TariffRepositoryImpl tariffs;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await deleteDatabase(inMemoryDatabasePath);
    db = await DatabaseHelper.openAt(inMemoryDatabasePath);
    holidays = HolidayRepositoryImpl(() async => db);
    tariffs = TariffRepositoryImpl(() async => db);
    addTearDown(() => db.close());
  });

  const night = Tariff(
    id: 0,
    name: 'Noćna',
    startPrice: 300,
    pricePerKm: 100,
    waitingParaPerMin: 2000,
    minPrice: 350,
    schedule: TariffSchedule(days: TariffSchedule.allDays, startMinute: 1320, endMinute: 360),
  );

  test('raspored tarife se čuva i čita', () async {
    final id = await tariffs.save(night);
    final t = (await tariffs.getAll()).single;
    expect(t.id, id);
    expect(t.schedule!.days, TariffSchedule.allDays);
    expect(t.schedule!.startMinute, 1320);
    expect(t.schedule!.endMinute, 360);

    await tariffs.save(t.copyWith(clearSchedule: true));
    expect((await tariffs.getAll()).single.schedule, isNull);
  });

  test('praznici: upis, izmena, čitanje po datumu, brisanje', () async {
    final tid = await tariffs.save(night);
    expect(await holidays.getAll(), isEmpty); // nema ugrađenih praznika

    final id = await holidays.save(Holiday(name: 'Božić', month: 1, day: 7, tariffId: tid));
    await holidays.save(Holiday(name: 'Uskrs', month: 4, day: 12, year: 2026, tariffId: tid));
    var all = await holidays.getAll();
    expect(all.map((h) => h.name), ['Božić', 'Uskrs']);
    expect(all.first.recurring, true);
    expect(all.last.year, 2026);

    await holidays.save(Holiday(id: id, name: 'Božić (pravoslavni)', month: 1, day: 7, tariffId: tid));
    all = await holidays.getAll();
    expect(all.first.name, 'Božić (pravoslavni)');

    await holidays.delete(id);
    expect((await holidays.getAll()).single.name, 'Uskrs');
  });

  test('nevalidan praznik se ne upisuje', () async {
    expect(() => holidays.save(const Holiday(name: 'x', month: 2, day: 30, tariffId: 1)),
        throwsArgumentError);
  });

  test('brisanje tarife briše i njene praznike', () async {
    final tid = await tariffs.save(night);
    await holidays.save(Holiday(name: 'x', month: 5, day: 1, tariffId: tid));
    await tariffs.delete(tid);
    expect(await holidays.getAll(), isEmpty);
  });

  test('stari redovi bez tarife se preskaču', () async {
    await db.insert('holidays', {
      'name': 'stari', 'date_string': '01-01', 'multiplier': 1.5, 'recurring_yearly': 1,
    });
    expect(await holidays.getAll(), isEmpty);
  });
}
