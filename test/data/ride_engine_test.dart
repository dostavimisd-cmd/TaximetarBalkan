import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taksimetar_balkan/data/database_helper.dart';
import 'package:taksimetar_balkan/data/services/ride_engine.dart';
import 'package:taksimetar_balkan/domain/models/location_point.dart';

const int t0 = 1760000000000; // fiksni UTC trenutak za testove
const int min = 60 * 1000;

const Map<String, dynamic> startCmd = {
  'command': 'start',
  'tariff_id': 1,
  'start_price': 200,
  'price_per_km': 100,
  'waiting_price_per_min': 10,
  'min_price': 0,
  'calibration': 1.0,
};

class Harness {
  Harness(this.db);

  final Database db;
  final List<Map<String, dynamic>> events = [];
  int now = t0;
  int trackingStarts = 0;
  int trackingStops = 0;

  late RideEngine engine = newEngine();

  /// Novi engine nad istom bazom = servis podignut iz početka (posle pada).
  RideEngine newEngine() => RideEngine(
        database: () async => db,
        send: events.add,
        nowMs: () => now,
        onTrackingStart: () => trackingStarts++,
        onTrackingStop: () async => trackingStops++,
      );

  Iterable<Map<String, dynamic>> of(String type) =>
      events.where((e) => e['event'] == type);

  /// Vožnja ~10 m/s na sever, jedna tačka u sekundi.
  void drive(int seconds, {int fromMs = t0}) {
    for (var i = 0; i <= seconds; i++) {
      engine.onPosition(LocationPoint(
        latitude: 44.8 + i * 0.00009,
        longitude: 20.46,
        accuracy: 5,
        speed: 10,
        timestamp: DateTime.fromMillisecondsSinceEpoch(fromMs + i * 1000,
            isUtc: true),
      ));
    }
  }

  Future<List<Map<String, Object?>>> rides() => db.query('rides', orderBy: 'id');
  Future<int> snapshotCount() async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM ride_snapshots')).first['n'] as int;
}

void main() {
  late Harness h;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await deleteDatabase(inMemoryDatabasePath);
    h = Harness(await DatabaseHelper.openAt(inMemoryDatabasePath));
    addTearDown(() => h.db.close());
  });

  test('10/13: start → stop upisuje iznose, completed, bez snapshot-a', () async {
    await h.engine.receive(startCmd);
    expect(h.of('started').single['ride_id'], isNotNull);
    expect(h.trackingStarts, 1);

    h.drive(60);
    await h.engine.saveSnapshot();
    expect(await h.snapshotCount(), 1);

    h.now = t0 + 61 * 1000;
    await h.engine.receive({'command': 'stop'});

    final stopped = h.of('stopped').single;
    final ride = (await h.rides()).single;
    expect(ride['status'], RideEngine.statusCompleted);
    expect(ride['total_price'], stopped['total_price']);
    expect(ride['km_price'], stopped['km_price']);
    expect(ride['distance_m'], stopped['distance_m']);
    expect(stopped['distance_m'] as int, greaterThan(500));
    expect(stopped['total_price'],
        (stopped['start_price'] as int) + (stopped['km_price'] as int) +
            (stopped['waiting_price'] as int) +
            (stopped['min_price_adjustment'] as int));
    expect(await h.snapshotCount(), 0);
    expect(h.trackingStops, 1);

    // snapshot posle stopa ne sme da napravi red
    await h.engine.saveSnapshot();
    expect(await h.snapshotCount(), 0);
  });

  test('11: greška upisa pri stopu → error{cmd:stop}, tracker ostaje, drugi stop uspeva',
      () async {
    await h.engine.receive(startCmd);
    h.drive(30);

    await h.db.execute('ALTER TABLE rides RENAME TO rides_tmp');
    await h.engine.receive({'command': 'stop'});
    expect(h.of('error').single['cmd'], 'stop');
    expect(h.of('stopped'), isEmpty);
    expect(h.engine.hasActiveRide, true);
    expect(h.trackingStops, 0);

    await h.db.execute('ALTER TABLE rides_tmp RENAME TO rides');
    await h.engine.receive({'command': 'stop'});
    expect(h.of('stopped').single['ride_id'], isNotNull);
    expect((await h.rides()).single['status'], RideEngine.statusCompleted);
  });

  test('12: red komandi start+stop bez await-a → 1 vožnja, completed', () async {
    // komande stižu jedna za drugom, bez čekanja (kao iz UI-ja)
    h.engine.receive(startCmd);
    h.engine.receive(startCmd);
    await h.engine.receive({'command': 'stop'});

    final rides = await h.rides();
    expect(rides.length, 1);
    expect(rides.single['status'], RideEngine.statusCompleted);
    expect(h.of('already_active').length, 1);
    expect(h.events.map((e) => e['event']),
        ['started', 'already_active', 'stopped']);
  });

  test('stop bez vožnje → stopped{ride_id:null}', () async {
    await h.engine.receive({'command': 'stop'});
    expect(h.of('stopped').single['ride_id'], isNull);
  });

  test('start sa nepotpunom tarifom → error{cmd:start}, nema reda', () async {
    await h.engine.receive({'command': 'start', 'tariff_id': 1});
    expect(h.of('error').single['cmd'], 'start');
    expect(await h.rides(), isEmpty);
  });

  test('ready{active:false} kad nema vožnje, bez praćenja', () async {
    expect(await h.engine.onServiceStart(), false);
    expect(h.of('ready').single['active'], false);
    expect(h.trackingStarts, 0);
  });

  test('6: pad servisa, snapshot < 5 min → recovered sa vrednostima', () async {
    await h.engine.receive(startCmd);
    h.drive(60);
    await h.engine.saveSnapshot();
    final distance = h.engine.tracker!.totalDistanceMeters;

    // servis ubijen; novi engine nad istom bazom 2 min kasnije
    h.now = t0 + 60 * 1000 + 2 * min;
    h.events.clear();
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);

    final recovered = h.of('recovered').single;
    expect(recovered['distance'], closeTo(distance, 0.001));
    expect(h.of('ready').single['active'], true);
    expect(engine2.hasActiveRide, true);

    // oporavljena vožnja može normalno da se završi
    await engine2.receive({'command': 'stop'});
    expect((await h.rides()).single['status'], RideEngine.statusCompleted);
  });

  test('7/K1: pad servisa, snapshot > 5 min → upisani iznosi, 0 snapshot-a',
      () async {
    await h.engine.receive(startCmd);
    h.drive(60);
    await h.engine.saveSnapshot();
    final distance = h.engine.tracker!.totalDistanceMeters.round();
    final expectedFare = h.engine.tracker!.currentFare!;

    h.now = t0 + 6 * min;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), false);

    final ride = (await h.rides()).single;
    expect(ride['status'], RideEngine.statusInterrupted);
    expect(ride['end_time'], t0 + 60 * 1000);
    expect(ride['distance_m'], distance);
    expect(ride['total_price'], expectedFare.totalPrice);
    expect(ride['km_price'], expectedFare.kmPrice);
    expect(ride['total_price'] as int, greaterThan(200));
    expect(await h.snapshotCount(), 0);
  });

  test('N5: starost snapshot-a se meri saved_at, ne GPS vremenom', () async {
    await h.engine.receive(startCmd);
    h.drive(30);
    h.now = t0 + 10 * min; // GPS vreme je staro, ali upis je svež
    await h.engine.saveSnapshot();

    h.now = t0 + 11 * min;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    expect(h.of('recovered'), isNotEmpty);
  });

  test('8: novi start zatvara zaostale aktivne vožnje kao interrupted', () async {
    for (var i = 0; i < 2; i++) {
      await h.db.insert('rides', {
        'start_time': t0 - 3600 * 1000,
        'distance_m': 0,
        'waiting_time_sec': 0,
        'start_price': 200,
        'km_price': 0,
        'waiting_price': 0,
        'total_price': 200,
        'tariff_id': 1,
        'applied_calibration': 1.0,
        'status': RideEngine.statusActive,
      });
    }
    await h.engine.receive(startCmd);

    final statuses = (await h.rides()).map((r) => r['status']).toList();
    expect(statuses, [
      RideEngine.statusInterrupted,
      RideEngine.statusInterrupted,
      RideEngine.statusActive,
    ]);
  });

  test('9/N6: bez snapshot-a sveža vožnja nastavlja od nule', () async {
    await h.engine.receive(startCmd); // nema GPS fix-a → nema snapshot-a
    h.now = t0 + 2 * min;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    expect(engine2.hasActiveRide, true);
    expect(h.of('recovered').single['distance'], 0.0);
    expect((await h.rides()).single['status'], RideEngine.statusActive);
  });

  test('9/N6: bez snapshot-a stara vožnja postaje interrupted, end=start',
      () async {
    await h.engine.receive(startCmd);
    h.now = t0 + 10 * min;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), false);
    final ride = (await h.rides()).single;
    expect(ride['status'], RideEngine.statusInterrupted);
    expect(ride['end_time'], ride['start_time']);
  });

  test('8/K1: zaostala aktivna vožnja sa snapshot-om dobija iznose pri startu',
      () async {
    await h.engine.receive(startCmd);
    h.drive(60);
    await h.engine.saveSnapshot();
    final expected = h.engine.tracker!.currentFare!.totalPrice;

    // pad, pa korisnik odmah pokrene novu vožnju (bez oporavka)
    h.now = t0 + 61 * 1000;
    final engine2 = h.newEngine();
    await engine2.receive(startCmd);

    final rides = await h.rides();
    expect(rides[0]['status'], RideEngine.statusInterrupted);
    expect(rides[0]['total_price'], expected);
    expect(rides[1]['status'], RideEngine.statusActive);
    expect(await h.snapshotCount(), 0);
  });

  test('status odražava aktivnu vožnju', () async {
    await h.engine.receive({'command': 'status'});
    expect(h.of('status').last['active'], false);
    await h.engine.receive(startCmd);
    h.drive(10);
    await h.engine.receive({'command': 'status'});
    final status = h.of('status').last;
    expect(status['active'], true);
    expect(status['distance'] as double, greaterThan(50));
  });
}
