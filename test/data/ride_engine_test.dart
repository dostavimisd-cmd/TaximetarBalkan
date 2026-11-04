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

  test('GPS prag tačnosti: tačka 20 m se odbacuje pri pragu 15, prihvata pri 25', () async {
    LocationPoint p(int i, double acc) => LocationPoint(
          latitude: 44.8 + i * 0.00009, longitude: 20.46, accuracy: acc, speed: 10,
          timestamp: DateTime.fromMillisecondsSinceEpoch(t0 + i * 1000, isUtc: true),
        );
    await h.engine.receive(startCmd); // bez gps_accuracy_m → 15 m
    for (var i = 0; i <= 10; i++) {
      h.now = t0 + i * 1000;
      h.engine.onPosition(p(i, 20));
    }
    expect(h.engine.tracker!.lastValidPoint, isNull);
    await h.engine.receive({'command': 'stop'});

    await h.engine.receive({...startCmd, 'gps_accuracy_m': 25});
    for (var i = 0; i <= 10; i++) {
      h.now = t0 + i * 1000;
      h.engine.onPosition(p(i, 20));
    }
    expect(h.engine.tracker!.totalDistanceMeters, greaterThan(50));
    expect((await h.rides()).last['gps_accuracy_m'], 25);

    // oporavak zadržava prag vožnje
    await h.engine.saveSnapshot();
    h.now += 30 * 1000;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    expect(engine2.tracker!.filter.accuracyThresholdMeters, 25.0);
  });

  test('GPS prag van opsega → error{cmd:start}', () async {
    for (final bad in [0, 4, 51]) {
      await h.engine.receive({...startCmd, 'gps_accuracy_m': bad});
    }
    expect(h.of('error').length, 3);
    expect(await h.rides(), isEmpty);
  });

  test('fiksna relacija: meri se put, naplaćuje fiksna cena', () async {
    await h.engine.receive({...startCmd, 'fixed_price': 2000, 'fixed_route_name': 'Aerodrom'});
    h.drive(60);
    expect(h.of('update').last['price'], 2000);
    expect(h.of('update').last['fixed_route_name'], 'Aerodrom');
    await h.engine.receive({'command': 'stop'});

    final stopped = h.of('stopped').single;
    expect(stopped['total_price'], 2000);
    expect(stopped['km_price'], 0);
    expect(stopped['distance_m'] as int, greaterThan(500)); // put se ipak meri
    expect(stopped['fixed_route_name'], 'Aerodrom');
    final ride = (await h.rides()).single;
    expect(ride['fixed_price'], 2000);
    expect(ride['fixed_route_name'], 'Aerodrom');
    expect(ride['total_price'], 2000);

    // sledeća vožnja je opet po tarifi
    h.events.clear();
    await h.engine.receive(startCmd);
    h.drive(10, fromMs: h.now + 1000);
    expect(h.of('update').last['price'], isNot(2000));
    expect(h.of('update').last.containsKey('fixed_route_name'), false);
  });

  test('fiksna relacija se oporavlja i prekid zadržava fiksnu cenu', () async {
    await h.engine.receive({...startCmd, 'fixed_price': 1500, 'fixed_route_name': 'Novi Sad'});
    h.drive(30);
    await h.engine.saveSnapshot();

    h.now += 60 * 1000;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    expect(h.of('recovered').single['price'], 1500);
    expect(h.of('recovered').single['fixed_route_name'], 'Novi Sad');

    // pad posle oporavka, pa novi start: prekinuta vožnja dobija fiksnu cenu
    await engine2.saveSnapshot();
    h.now += 60 * 1000;
    final engine3 = h.newEngine();
    await engine3.receive(startCmd);
    final first = (await h.rides()).first;
    expect(first['status'], RideEngine.statusInterrupted);
    expect(first['total_price'], 1500);
  });

  test('neispravna fiksna cena → error{cmd:start}', () async {
    await h.engine.receive({...startCmd, 'fixed_price': 0});
    await h.engine.receive({...startCmd, 'fixed_price': -5});
    expect(h.of('error').length, 2);
    expect(await h.rides(), isEmpty);
  });

  test('pauza: tokom pauze nema km ni čekanja; posle nastavka pauza se ne naplaćuje', () async {
    await h.engine.receive(startCmd);
    h.drive(20);
    final distanceBefore = h.engine.tracker!.totalDistanceMeters;
    final waitingBefore = h.engine.tracker!.totalWaitingMs;
    final priceBefore = h.of('update').last['price'];

    await h.engine.receive({'command': 'pause'});
    expect(h.of('paused').single['paused'], true);
    // 3 minuta vožnje i stajanja za vreme pauze: ništa se ne računa
    final t = h.engine.tracker!.lastValidPoint!.timestamp.millisecondsSinceEpoch;
    h.now = t + 3 * 60 * 1000;
    h.engine.onPosition(LocationPoint(
      latitude: 44.9, longitude: 20.5, accuracy: 5, speed: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(h.now, isUtc: true),
    ));
    expect(h.engine.tracker!.totalDistanceMeters, distanceBefore);
    expect(h.engine.tracker!.totalWaitingMs, waitingBefore);

    await h.engine.receive({'command': 'resume'});
    expect(h.of('resumed').single['paused'], false);
    expect(h.of('resumed').single['paused_sec'], 180);

    // prva tačka posle nastavka je samo polazna: bez skoka distance i bez rupe
    final events = h.events.length;
    h.drive(5, fromMs: h.now + 1000);
    expect(h.of('gap').isEmpty, true);
    expect(h.engine.tracker!.totalDistanceMeters - distanceBefore, lessThan(80));
    expect(h.of('update').last['price'], greaterThanOrEqualTo(priceBefore as int));
    expect(h.events.length, greaterThan(events));

    await h.engine.receive({'command': 'stop'});
    expect(h.of('stopped').single['paused_sec'], 180);
    expect((await h.rides()).single['paused_sec'], 180);
  });

  test('stop dok je pauzirano završava vožnju i računa pauzu', () async {
    await h.engine.receive(startCmd);
    h.drive(10);
    await h.engine.receive({'command': 'pause'});
    h.now += 90 * 1000;
    await h.engine.receive({'command': 'stop'});
    expect(h.of('stopped').single['paused_sec'], 90);
    expect((await h.rides()).single['status'], RideEngine.statusCompleted);
    expect(h.engine.hasActiveRide, false);
  });

  test('pauza i nastavak bez vožnje ili dvaput ne rade ništa', () async {
    await h.engine.receive({'command': 'pause'});
    expect(h.of('paused'), isEmpty);
    await h.engine.receive(startCmd);
    await h.engine.receive({'command': 'resume'});
    expect(h.of('resumed'), isEmpty);
    await h.engine.receive({'command': 'pause'});
    await h.engine.receive({'command': 'pause'});
    expect(h.of('paused').length, 1);
  });

  test('ruta: tačke se upisuju retko i brišu sa vožnjom; pauza ne dodaje tačke', () async {
    await h.engine.receive(startCmd);
    h.drive(60); // ~600 m, tačka u sekundi
    await h.engine.saveSnapshot();
    final stored = await h.db.query('ride_points', orderBy: 'ts');
    expect(stored.length, inInclusiveRange(10, 60)); // retko: ne svaka sekunda
    for (var i = 1; i < stored.length; i++) {
      expect((stored[i]['ts'] as int) - (stored[i - 1]['ts'] as int), greaterThanOrEqualTo(5000));
    }
    expect(stored.first['ride_id'], h.engine.currentRideId);

    await h.engine.receive({'command': 'pause'});
    final before = stored.length;
    h.drive(30, fromMs: h.now + 1000);
    await h.engine.saveSnapshot();
    expect((await h.db.query('ride_points')).length, before);

    await h.engine.receive({'command': 'stop'});
    expect((await h.db.query('ride_points')).length, greaterThanOrEqualTo(before));
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

  test('doplata: dodaje se na cenu, upisuje odmah i ulazi u ukupno', () async {
    await h.engine.receive({...startCmd, 'min_price': 500});
    h.drive(10);
    await h.engine.receive({'command': 'add_extra', 'name': 'Prtljag', 'amount': 100});
    final u = h.of('update').last;
    expect(u['extras_total'], 100);
    expect(u['price'], 500 + 100); // minimalna pa doplata
    expect((await h.db.query('ride_extras')).single['name'], 'Prtljag');

    await h.engine.receive({'command': 'add_extra', 'name': 'Noćna', 'amount': 50});
    final id = ((h.of('update').last['extras'] as List).last as Map)['id'];
    await h.engine.receive({'command': 'remove_extra', 'id': id});
    expect(h.of('update').last['extras_total'], 100);

    await h.engine.receive({'command': 'stop'});
    final stopped = h.of('stopped').single;
    expect(stopped['extras_total'], 100);
    expect(stopped['total_price'], 600);
    expect(stopped['min_price_adjustment'], greaterThan(0));
    final ride = (await h.rides()).single;
    expect(ride['extras_total'], 100);
    expect(ride['total_price'], 600);
  });

  test('doplata: neispravna ili bez vožnje se ne dodaje', () async {
    await h.engine.receive({'command': 'add_extra', 'name': 'X', 'amount': 100});
    expect(await h.db.query('ride_extras'), isEmpty);
    await h.engine.receive(startCmd);
    await h.engine.receive({'command': 'add_extra', 'name': '', 'amount': 100});
    await h.engine.receive({'command': 'add_extra', 'name': 'X', 'amount': 0});
    expect(await h.db.query('ride_extras'), isEmpty);
    expect(h.of('error'), hasLength(2));
  });

  test('doplata i prvi km se oporavljaju; prekid zadržava doplatu', () async {
    await h.engine.receive({...startCmd, 'first_km_price': 0});
    h.drive(30);
    await h.engine.receive({'command': 'add_extra', 'name': 'Prtljag', 'amount': 100});
    await h.engine.saveSnapshot();
    expect((await h.rides()).single['tariff_first_km_price'], 0);

    h.now += min;
    final engine2 = h.newEngine();
    expect(await engine2.onServiceStart(), true);
    final rec = h.of('recovered').single;
    expect(rec['extras_total'], 100);
    // ~300 m, prvi km u startu: 200 + 0 + doplata
    expect(rec['price'], 300);

    await engine2.saveSnapshot();
    h.now += 10 * min;
    await h.newEngine().receive(startCmd);
    final first = (await h.rides()).first;
    expect(first['status'], RideEngine.statusInterrupted);
    expect(first['extras_total'], 100);
    expect(first['total_price'], 300);
  });
}
