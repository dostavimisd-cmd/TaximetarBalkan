import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';
import 'package:taksimetar_balkan/data/repositories/shift_repository_impl.dart';

void main() {
  late Database db;
  late ShiftRepositoryImpl repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await deleteDatabase(inMemoryDatabasePath);
    db = await DatabaseHelper.openAt(inMemoryDatabasePath);
    repo = ShiftRepositoryImpl(() async => db);
    addTearDown(() => db.close());
  });

  DateTime t(int h) => DateTime.utc(2026, 10, 19, h);

  test('nema smena na početku', () async {
    expect(await repo.getAll(), isEmpty);
    expect(await repo.current(), isNull);
  });

  test('počni → u toku; ponovni početak vraća istu smenu', () async {
    final s = await repo.start(t(8));
    expect(s.isOpen, true);
    expect((await repo.start(t(9))).id, s.id);
    expect((await repo.current())!.start, t(8));
  });

  test('završi → zatvorena; nova smena je prva u listi', () async {
    await repo.start(t(8));
    await repo.end(t(16));
    expect(await repo.current(), isNull);
    await repo.start(t(20));
    final all = await repo.getAll();
    expect(all.length, 2);
    expect(all.first.isOpen, true);
    expect(all.last.end, t(16));
  });

  test('kraj bez otvorene smene ne radi ništa', () async {
    await repo.end(t(10));
    expect(await repo.getAll(), isEmpty);
  });
}
