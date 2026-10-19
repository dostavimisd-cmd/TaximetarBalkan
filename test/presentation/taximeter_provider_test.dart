import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/presentation/providers/taximeter_provider.dart';
import 'package:taksimetar_balkan/presentation/services/ride_service_controller.dart';

class FakeController extends RideServiceController {
  final StreamController<Map<String, dynamic>> fakeEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  final Completer<bool> connectResult = Completer<bool>();

  @override
  Stream<Map<String, dynamic>> get events => fakeEvents.stream;

  final List<String> commands = [];

  @override
  Future<void> pauseRide() async => commands.add('pause');

  @override
  Future<void> resumeRide() async => commands.add('resume');

  @override
  Future<void> stopRide() async => commands.add('stop');

  bool startResult = true;
  int startCalls = 0;

  int connectCalls = 0;
  Future<bool> Function()? connectOverride;

  @override
  Future<bool> connect({bool requestPermissions = true}) {
    connectCalls++;
    return connectOverride != null ? connectOverride!() : connectResult.future;
  }

  @override
  Future<bool> startRide({
    required int tariffId,
    required int startPrice,
    required int pricePerKm,
    required int waitingParaPerMin,
    required int minPrice,
    required int calibrationPermille,
    int? waitingSpeedKmh,
    int? gpsAccuracyM,
    int? fixedPrice,
    String? fixedRouteName,
  }) async {
    startCalls++;
    return startResult;
  }
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeController fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeController();
    container = ProviderContainer(overrides: [
      rideServiceControllerProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    container.read(taximeterProvider); // build + pretplata
  });

  TaximeterState read() => container.read(taximeterProvider);

  test('K4: greška preživi niz update događaja', () async {
    fake.fakeEvents.add({'event': 'error', 'message': 'GPS problem'});
    await pump();
    for (var i = 0; i < 10; i++) {
      fake.fakeEvents.add({'event': 'update', 'distance': 10.0 * i, 'price': 250});
    }
    await pump();
    expect(read().errorMessage, 'GPS problem');
    expect(read().currentDistanceMeters, 90.0);
  });

  test('K4: upozorenje preživi update i završetak connect()', () async {
    fake.fakeEvents.add({'event': 'warning', 'message': 'Notifikacije isključene'});
    await pump();
    fake.fakeEvents.add({'event': 'update', 'distance': 5.0, 'price': 250});
    fake.connectResult.complete(true);
    await pump();
    expect(read().isReady, true);
    expect(read().warningMessage, 'Notifikacije isključene');
  });

  test('K4: greška iz connect() ne briše se kad connect vrati false', () async {
    fake.fakeEvents.add({'event': 'error', 'message': 'Servis ne odgovara.'});
    fake.connectResult.complete(false);
    await pump();
    expect(read().isReady, false);
    expect(read().errorMessage, 'Servis ne odgovara.');
  });

  test('K4: ready, started i stopped eksplicitno brišu grešku', () async {
    for (final event in ['ready', 'started', 'stopped']) {
      fake.fakeEvents.add({'event': 'error', 'message': 'x'});
      await pump();
      expect(read().errorMessage, 'x');
      fake.fakeEvents.add({'event': event});
      await pump();
      expect(read().errorMessage, isNull, reason: event);
    }
  });

  test('K6/N2: error{cmd:start} vraća UI u mirovanje', () async {
    fake.connectResult.complete(true);
    fake.fakeEvents.add({'event': 'started'});
    await pump();
    expect(read().isRunning, true);
    fake.fakeEvents.add(
        {'event': 'error', 'cmd': 'start', 'message': 'Baza ne radi'});
    await pump();
    expect(read().isRunning, false);
    expect(read().errorMessage, 'Baza ne radi');
  });

  test('K6/N3: error{cmd:stop} ostavlja vožnju aktivnom', () async {
    fake.fakeEvents.add({'event': 'started'});
    await pump();
    fake.fakeEvents
        .add({'event': 'error', 'cmd': 'stop', 'message': 'Upis pao'});
    await pump();
    expect(read().isRunning, true);
    expect(read().errorMessage, 'Upis pao');
  });

  test('error bez cmd ne menja isRunning', () async {
    fake.fakeEvents.add({'event': 'started'});
    await pump();
    fake.fakeEvents.add({'event': 'error', 'message': 'GPS šum'});
    await pump();
    expect(read().isRunning, true);
  });

  test('K3: stopped nosi rezultat, faza finished, cena ostaje', () async {
    fake.fakeEvents.add({'event': 'started'});
    await pump();
    fake.fakeEvents.add({
      'event': 'stopped',
      'ride_id': 7,
      'distance_m': 1500,
      'waiting_sec': 90,
      'start_price': 200,
      'km_price': 150,
      'waiting_price': 30,
      'min_price_adjustment': 0,
      'total_price': 380,
    });
    await pump();
    expect(read().phase, RidePhase.finished);
    expect(read().isRunning, false);
    expect(read().currentPrice, 380);
    expect(read().lastResult?.rideId, 7);
    expect(read().lastResult?.kmPrice, 150);

    // zakasneli update ne sme da pokvari prikaz završene cene
    fake.fakeEvents.add({'event': 'update', 'price': 5, 'distance': 1.0});
    await pump();
    expect(read().currentPrice, 380);
  });

  test('K3: newRide vraća ekran u idle sa nulama', () async {
    fake.fakeEvents.add({'event': 'stopped', 'ride_id': 1, 'total_price': 300});
    await pump();
    expect(read().phase, RidePhase.finished);
    container.read(taximeterProvider.notifier).newRide();
    expect(read().phase, RidePhase.idle);
    expect(read().currentPrice, 0);
    expect(read().lastResult, isNull);
  });

  test('K3: stopped bez ride_id vraća idle', () async {
    fake.fakeEvents.add({'event': 'started'});
    await pump();
    fake.fakeEvents.add({'event': 'stopped', 'ride_id': null});
    await pump();
    expect(read().phase, RidePhase.idle);
    expect(read().lastResult, isNull);
  });

  Future<void> startViaNotifier() =>
      container.read(taximeterProvider.notifier).startRide(
          startPrice: 200, pricePerKm: 100, waitingParaPerMin: 1000, minPrice: 300);

  test('startRide koji nije poslat vraća prethodnu fazu i rezultat', () async {
    fake.connectResult.complete(true);
    await pump();
    fake.fakeEvents.add({'event': 'stopped', 'ride_id': 3, 'total_price': 450});
    await pump();
    fake.startResult = false;
    await startViaNotifier();
    expect(read().phase, RidePhase.finished);
    expect(read().currentPrice, 450);
    expect(read().lastResult?.rideId, 3);
  });

  test('startRide: starting odmah blokira drugi pritisak', () async {
    fake.connectResult.complete(true);
    await pump();
    final first = startViaNotifier();
    expect(read().phase, RidePhase.starting);
    await startViaNotifier();
    await first;
    expect(fake.startCalls, 1);
  });

  test('V7: recovered preuzima vrednosti i upozorenje', () async {
    fake.fakeEvents.add({
      'event': 'recovered',
      'ride_id': 4,
      'distance': 1234.0,
      'waitingMs': 45000,
      'price': 420,
    });
    await pump();
    expect(read().phase, RidePhase.running);
    expect(read().currentDistanceMeters, 1234.0);
    expect(read().currentWaitingMs, 45000);
    expect(read().currentPrice, 420);
    expect(read().warningMessage, isNotNull);
  });

  test('V8: retryConnect posle neuspelog connect-a', () async {
    fake.connectResult.complete(false);
    await pump();
    expect(read().isReady, false);

    fake.connectOverride = () async => true;
    await container.read(taximeterProvider.notifier).retryConnect();
    expect(read().isReady, true);
    expect(fake.connectCalls, 2);
  });

  test('N10: mode update pali i gasi trenutno čekanje', () async {
    fake.fakeEvents.add({'event': 'started'});
    fake.fakeEvents.add({'event': 'update', 'waitingMs': 5000, 'mode': 'waiting'});
    await pump();
    expect(read().isWaitingNow, true);
    fake.fakeEvents.add({'event': 'update', 'waitingMs': 5000, 'mode': 'driving'});
    await pump();
    expect(read().isWaitingNow, false);
    expect(read().currentWaitingMs, 5000);
  });

  test('N11: recovered i status nose tarifu vožnje', () async {
    fake.fakeEvents.add({
      'event': 'recovered', 'distance': 10.0, 'waitingMs': 0, 'price': 300,
      'tariff_id': 3, 'start_price': 350, 'mode': 'driving',
    });
    await pump();
    expect(read().selectedTariffId, 3);
    expect(read().rideStartPrice, 350);

    fake.fakeEvents.add({'event': 'stopped', 'ride_id': 1, 'total_price': 400});
    await pump();
    expect(read().rideStartPrice, isNull);
    expect(read().selectedTariffId, 3); // izbor tarife za sledeću vožnju ostaje
  });

  test('prag brzine iz status/recovered/update događaja', () async {
    fake.fakeEvents.add({'event': 'recovered', 'waiting_speed_kmh': 5});
    await pump();
    expect(read().waitingSpeedKmh, 5);
    fake.fakeEvents.add({'event': 'update', 'waiting_speed_kmh': 6});
    await pump();
    expect(read().waitingSpeedKmh, 6);
  });

  test('pauza i nastavak: faza, komande servisu, isRunning ostaje', () async {
    final n = container.read(taximeterProvider.notifier);
    fake.fakeEvents.add({'event': 'started'});
    await pump();
    expect(read().phase, RidePhase.running);

    await n.pauseRide();
    expect(read().phase, RidePhase.paused);
    expect(read().isRunning, true); // vožnja je i dalje u toku
    expect(read().pausedSince, isNotNull);
    expect(fake.commands, ['pause']);

    fake.fakeEvents.add({'event': 'update', 'price': 300, 'distance': 500.0});
    await pump();
    expect(read().phase, RidePhase.paused); // update ne vraća u vožnju

    await n.resumeRide();
    expect(read().phase, RidePhase.running);
    expect(read().pausedSince, isNull);
    expect(fake.commands, ['pause', 'resume']);
  });

  test('pauza se ne šalje van vožnje, nastavak samo iz pauze', () async {
    final n = container.read(taximeterProvider.notifier);
    await n.pauseRide();
    await n.resumeRide();
    expect(fake.commands, isEmpty);
    expect(read().phase, RidePhase.idle);
  });

  test('stop iz pauze je dozvoljen; status sa paused vraća pauzu', () async {
    final n = container.read(taximeterProvider.notifier);
    fake.fakeEvents.add({'event': 'status', 'active': true, 'paused': true, 'price': 300});
    await pump();
    expect(read().phase, RidePhase.paused);
    await n.stopRide();
    expect(read().phase, RidePhase.stopping);
    expect(fake.commands, ['stop']);
  });

  test('paused/resumed događaji iz servisa i pauza u rezultatu', () async {
    fake.fakeEvents.add({'event': 'started'});
    fake.fakeEvents.add({'event': 'paused'});
    await pump();
    expect(read().phase, RidePhase.paused);
    fake.fakeEvents.add({'event': 'resumed'});
    await pump();
    expect(read().phase, RidePhase.running);
    fake.fakeEvents.add({'event': 'stopped', 'ride_id': 3, 'total_price': 500, 'paused_sec': 125});
    await pump();
    expect(read().lastResult!.pausedSeconds, 125);
  });

  test('copyWith: clearWarning briše upozorenje', () {
    const s = TaximeterState(warningMessage: 'w', errorMessage: 'e');
    expect(s.copyWith(clearWarning: true).warningMessage, isNull);
    expect(s.copyWith(clearWarning: true).errorMessage, 'e');
    expect(s.copyWith(currentPrice: 5).warningMessage, 'w');
  });
}
