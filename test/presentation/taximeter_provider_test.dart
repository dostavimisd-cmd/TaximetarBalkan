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

  @override
  Future<bool> connect() => connectResult.future;
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

  test('copyWith: clearWarning briše upozorenje', () {
    const s = TaximeterState(warningMessage: 'w', errorMessage: 'e');
    expect(s.copyWith(clearWarning: true).warningMessage, isNull);
    expect(s.copyWith(clearWarning: true).errorMessage, 'e');
    expect(s.copyWith(currentPrice: 5).warningMessage, 'w');
  });
}
