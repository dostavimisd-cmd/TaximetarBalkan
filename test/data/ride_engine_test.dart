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
  'waiting_para_per_min': 1000,
  'min_price': 0,
  'calibration_permille': 1000,
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
      now = fromMs + i * 1000; // sat telefona prati GPS vreme
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

  test('N19: start sa negativnom cenom → error{cmd:start}, nema reda', () async {
    await h.engine.receive({...startCmd, 'price_per_km': -100});
    expect(h.of('error').single['cmd'], 'start');
    expect(h.engine.hasActiveRide, false);
    expect(await h.rides(), isEmpty);
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

    h.now = t0 + 7 * min;
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

  test('N1: tačka +1 h ne zamrzava vožnju', () async {
    await h.engine.receive(startCmd);
    h.drive(20);
    final before = h.engine.tracker!.totalDistanceMeters;

    h.engine.onPosition(LocationPoint(
      latitude: 44.9, longitude: 20.46, accuracy: 5, speed: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(h.now + 60 * min, isUtc: true),
    ));
    expect(h.engine.tracker!.totalDistanceMeters, before);

    // vožnja nastavlja normalno
    h.drive(10, fromMs: h.now + 1000);
    expect(h.engine.tracker!.totalDistanceMeters, greaterThan(before + 50));
  });

  test('review: prekid servisa se ne naplaćuje kao čekanje', () async {
    await h.engine.receive(startCmd);
    h.drive(60);
    await h.engine.saveSnapshot();
    final waitingBefore = h.engine.tracker!.totalWaitingMs;
    final distanceBefore = h.engine.tracker!.totalDistanceMeters;

    // servis ubijen, aplikacija otvorena posle 4 min
    final resumeAt = h.now + 4 * min;
    h.now = resumeAt;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    h.engine = engine2;
    h.drive(5, fromMs: resumeAt);

    expect(engine2.tracker!.totalWaitingMs - waitingBefore, lessThan(10 * 1000));
    expect(engine2.tracker!.totalDistanceMeters,
        lessThan(distanceBefore + 100)); // samo novih 5 s vožnje
  });

  test('review: snapshot pokrenut tik pre stopa ne ostavlja red', () async {
    await h.engine.receive(startCmd);
    h.drive(30);
    final snap = h.engine.saveSnapshot(); // timer okinuo, bez await-a
    final stop = h.engine.receive({'command': 'stop'});
    await Future.wait([snap, stop]);
    expect(await h.snapshotCount(), 0);
    expect((await h.rides()).single['status'], RideEngine.statusCompleted);
  });

  test('N10/N11: update i status nose mode i tarifu', () async {
    await h.engine.receive(startCmd);
    h.drive(20); // ~36 km/h: vožnja
    expect(h.of('update').last['mode'], 'driving');
    expect(h.of('update').last['tariff_id'], 1);

    // stajanje: iste koordinate 30 s, brzina 0
    final last = h.engine.tracker!.lastValidPoint!;
    for (var i = 1; i <= 30; i++) {
      h.now = last.timestamp.millisecondsSinceEpoch + i * 1000;
      h.engine.onPosition(LocationPoint(
        latitude: last.latitude, longitude: last.longitude, accuracy: 5, speed: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(h.now, isUtc: true),
      ));
    }
    expect(h.of('update').last['mode'], 'waiting');
    await h.engine.receive({'command': 'status'});
    expect(h.of('status').last['mode'], 'waiting');
    expect(h.of('status').last['start_price'], 200);
  });

  /// Sporo kretanje: ~5 km/h (1,4 m/s) pravo na sever, jedna tačka u sekundi.
  Future<void> crawl(int seconds) async {
    final t0p = h.engine.tracker?.lastValidPoint?.timestamp.millisecondsSinceEpoch ?? t0;
    for (var i = 1; i <= seconds; i++) {
      h.now = t0p + i * 1000;
      h.engine.onPosition(LocationPoint(
        latitude: 44.8 + i * 0.0000126,
        longitude: 20.46,
        accuracy: 5,
        speed: 1.4,
        timestamp: DateTime.fromMillisecondsSinceEpoch(h.now, isUtc: true),
      ));
    }
  }

  test('prag brzine: 5 km/h je čekanje pri pragu 8, a vožnja pri pragu 3', () async {
    await h.engine.receive(startCmd); // bez waiting_speed_kmh → 8
    await crawl(40);
    expect(h.engine.tracker!.totalWaitingMs, greaterThan(20000));
    final distanceAt8 = h.engine.tracker!.totalDistanceMeters;
    await h.engine.receive({'command': 'stop'});

    await h.engine.receive({...startCmd, 'waiting_speed_kmh': 3});
    await crawl(40);
    expect(h.engine.tracker!.totalWaitingMs, 0);
    expect(h.engine.tracker!.totalDistanceMeters, greaterThan(distanceAt8 + 20));
    expect((await h.rides()).last['waiting_speed_kmh'], 3);
    expect(h.of('update').last['waiting_speed_kmh'], 3);
  });

  test('prag brzine se oporavlja zajedno sa vožnjom', () async {
    await h.engine.receive({...startCmd, 'waiting_speed_kmh': 3});
    await crawl(30);
    await h.engine.saveSnapshot();
    final waited = h.engine.tracker!.totalWaitingMs;

    h.now += 60 * 1000;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    expect(engine2.tracker!.waiter.waitingSpeedThresholdKmh, 3.0);
    expect(engine2.tracker!.totalWaitingMs, waited);
  });

  test('prag brzine van opsega → error{cmd:start}', () async {
    for (final bad in [0, -5, 51, 500]) {
      await h.engine.receive({...startCmd, 'waiting_speed_kmh': bad});
    }
    expect(h.of('error').length, 4);
    expect(h.of('error').every((e) => e['cmd'] == 'start'), true);
    expect(await h.rides(), isEmpty);
  });

  test('kalibracija: promili se čuvaju i primenjuju na distancu u obračunu', () async {
    await h.engine.receive({...startCmd, 'calibration_permille': 1100});
    h.drive(60);
    final raw = h.engine.tracker!.totalDistanceMeters.round();
    await h.engine.receive({'command': 'stop'});

    final stopped = h.of('stopped').single;
    expect(stopped['distance_m'], raw); // zabeležena distanca je izmerena
    // obračun koristi 110% distance: km cena po 100 din/km
    final expectedKm = (((raw * 1100 + 500) ~/ 1000) * 100 + 500) ~/ 1000;
    expect(stopped['km_price'], expectedKm);
    expect((await h.rides()).single['applied_calibration'], 1.1);
  });

  test('kalibracija se oporavlja zajedno sa vožnjom', () async {
    await h.engine.receive({...startCmd, 'calibration_permille': 1025});
    h.drive(30);
    await h.engine.saveSnapshot();
    h.now += 30 * 1000;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    expect(engine2.tracker!.calibrationPermille, 1025);
  });

  test('kalibracija van opsega → error{cmd:start}', () async {
    for (final bad in [0, 499, 1501, -1000]) {
      await h.engine.receive({...startCmd, 'calibration_permille': bad});
    }
    expect(h.of('error').length, 4);
    expect(await h.rides(), isEmpty);
  });

  test('V12: rupa u signalu → gap događaj, red u ride_gaps, brojač u update', () async {
    await h.engine.receive(startCmd);
    h.drive(10);
    final last = h.engine.tracker!.lastValidPoint!;
    // rupa 60 s, stoji u mestu
    h.now = last.timestamp.millisecondsSinceEpoch + 60 * 1000;
    h.engine.onPosition(LocationPoint(
      latitude: last.latitude, longitude: last.longitude, accuracy: 5, speed: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(h.now, isUtc: true),
    ));
    await h.engine.receive({'command': 'status'}); // posle upisa u redu

    final gap = h.of('gap').single;
    expect(gap['kind'], 'waiting');
    expect(gap['duration_ms'], 60000);
    expect(h.of('update').last['gap_count'], 1);
    expect(h.of('update').last['gap_ms'], 60000);

    final rows = await h.db.query('ride_gaps');
    expect(rows.single['kind'], 'waiting');
    expect(rows.single['added_waiting_ms'], 60000);
    expect(rows.single['ride_id'], h.engine.currentRideId);
  });

  test('V12: oporavak upisuje rupu "servis zaustavljen" i vraća brojač', () async {
    await h.engine.receive(startCmd);
    h.drive(30);
    await h.engine.saveSnapshot();

    h.now += 2 * min;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);

    final rows = await h.db.query('ride_gaps');
    expect(rows.single['kind'], 'service_restart');
    expect(rows.single['duration_ms'], 2 * min);
    expect(rows.single['added_distance_m'], 0);
    expect(h.of('recovered').single['gap_count'], 1);
    expect(h.of('recovered').single['gap_ms'], 2 * min);
  });

  test('V12: nova vožnja kreće sa brojačem 0', () async {
    await h.engine.receive(startCmd);
    h.drive(5);
    final last = h.engine.tracker!.lastValidPoint!;
    h.now = last.timestamp.millisecondsSinceEpoch + 40 * 1000;
    h.engine.onPosition(LocationPoint(
      latitude: last.latitude, longitude: last.longitude, accuracy: 5, speed: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(h.now, isUtc: true),
    ));
    await h.engine.receive({'command': 'stop'});
    h.events.clear();

    await h.engine.receive(startCmd);
    h.drive(5, fromMs: h.now + 1000);
    expect(h.of('update').last['gap_count'], 0);
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
