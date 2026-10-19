import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/presentation/services/ride_service_controller.dart';

/// Simulira servis: startService → 'ready', start → 'started', stop → 'stopped'.
class FakeBridge implements ForegroundBridge {
  bool running = false;
  bool recoverOnStart = false;
  bool failStart = false;
  bool silent = false;
  int starts = 0;
  int stops = 0;
  final List<Map<String, dynamic>> sent = [];
  DataCallback? _callback;
  bool _rideInService = false;

  void _reply(Map<String, dynamic> event) =>
      scheduleMicrotask(() => _callback?.call(event));

  @override
  Future<bool> isRunningService() async => running;

  @override
  Future<String?> startService() async {
    starts++;
    running = true;
    _rideInService = recoverOnStart;
    if (recoverOnStart) _reply({'event': 'recovered', 'ride_id': 1});
    _reply({'event': 'ready', 'active': recoverOnStart});
    return null;
  }

  @override
  Future<void> stopService() async {
    stops++;
    running = false;
    _rideInService = false;
  }

  @override
  void sendToTask(Map<String, dynamic> data) {
    sent.add(data);
    if (silent) return;
    switch (data['command']) {
      case 'start':
        if (failStart) {
          _reply({'event': 'error', 'cmd': 'start', 'message': 'baza'});
          break;
        }
        _rideInService = true;
        _reply({'event': 'started', 'ride_id': 1});
        break;
      case 'stop':
        final had = _rideInService;
        _rideInService = false;
        _reply({'event': 'stopped', 'ride_id': had ? 1 : null});
        break;
      case 'status':
        _reply({'event': 'status', 'active': _rideInService});
        break;
    }
  }

  @override
  void addCallback(DataCallback callback) => _callback = callback;

  @override
  void removeCallback(DataCallback callback) => _callback = null;

  @override
  void init() {}
}

class TestController extends RideServiceController {
  TestController(FakeBridge bridge) : super(bridge: bridge);

  @override
  Future<bool> ensurePermissions({bool request = true}) async => true;
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<bool> start(RideServiceController c) => c.startRide(
      tariffId: 1,
      startPrice: 200,
      pricePerKm: 100,
      waitingPricePerMin: 10,
      minPrice: 300,
      calibration: 1.0,
    );

void main() {
  late FakeBridge bridge;
  late TestController controller;
  late List<Map<String, dynamic>> events;

  setUp(() {
    bridge = FakeBridge();
    controller = TestController(bridge);
    events = [];
    controller.events.listen(events.add);
    addTearDown(controller.dispose);
  });

  test('K5: connect bez vožnje gasi servis', () async {
    expect(await controller.connect(), true);
    expect(bridge.starts, 1);
    expect(bridge.stops, 1);
    expect(bridge.running, false);
  });

  test('connect sa oporavljenom vožnjom ostavlja servis da radi', () async {
    bridge.recoverOnStart = true;
    expect(await controller.connect(), true);
    expect(bridge.running, true);
    expect(controller.rideActive, true);
  });

  test('connect na servis koji radi bez vožnje ga gasi', () async {
    bridge.running = true;
    expect(await controller.connect(), true);
    expect(bridge.sent.single['command'], 'status');
    expect(bridge.running, false);
  });

  test('K2: dve vožnje zaredom, servis se pali za svaku', () async {
    await controller.connect();

    expect(await start(controller), true);
    await settle();
    expect(controller.rideActive, true);
    expect(bridge.running, true);

    await controller.stopRide();
    await settle();
    expect(controller.rideActive, false);
    expect(bridge.running, false);

    expect(await start(controller), true);
    await settle();
    expect(bridge.running, true);
    expect(bridge.starts, 3); // connect + 2 vožnje
    expect(events.where((e) => e['event'] == 'started').length, 2);
    expect(
        events.any((e) => e['message'] == 'Servis nije spreman.'), false);
  });

  test('startRide ne pravi novu vožnju kad servis oporavi staru', () async {
    bridge.recoverOnStart = true;
    expect(await start(controller), false);
    expect(bridge.sent.where((d) => d['command'] == 'start'), isEmpty);
  });

  test('dupli startRide šalje jedan start', () async {
    final results = await Future.wait([start(controller), start(controller)]);
    await settle();
    expect(results, [true, false]);
    expect(bridge.sent.where((d) => d['command'] == 'start').length, 1);
  });

  test('error{cmd:start} iz servisa gasi servis bez vožnje', () async {
    bridge.failStart = true;
    expect(await start(controller), true);
    await settle();
    expect(controller.rideActive, false);
    expect(bridge.running, false);

    // posle neuspeha novi start ponovo podiže servis
    bridge.failStart = false;
    expect(await start(controller), true);
    await settle();
    expect(controller.rideActive, true);
  });

  test('review: status timeout ostavlja serviceReady=false, stop ipak stiže',
      () async {
    bridge.running = true;
    bridge.silent = true;
    expect(await controller.connect(), false);
    expect(controller.serviceReady, false);
    expect(bridge.running, true); // vožnja možda postoji: servis se ne gasi

    await controller.stopRide();
    expect(bridge.sent.last['command'], 'stop');
    expect(events.any((e) => e['event'] == 'stopped'), false);
  });

  test('review: startRide na servis koji radi bez priključenja pita status',
      () async {
    bridge.running = true;
    expect(await start(controller), true);
    await settle();
    expect(bridge.starts, 0); // nije pokušan drugi startService
    expect(bridge.sent.map((d) => d['command']), ['status', 'start']);
  });

  test('stopRide kad servis ne radi vraća stopped bez ride_id', () async {
    await controller.stopRide();
    await settle();
    expect(events.first, {'event': 'stopped', 'ride_id': null});
  });
}
