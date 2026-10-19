import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/models/location_point.dart';
import '../database_helper.dart';
import 'ride_engine.dart';

@pragma('vm:entry-point')
void startCallback() {
  // Obavezno za stabilan rad baze i geolokatora unutar pozadinskog izolata
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(RideTaskHandler());
}

/// Lepak između plugin-a i [RideEngine]: prosleđuje komande i GPS tačke,
/// a GPS stream i snapshot timer drži otvorenim samo dok traje vožnja.
class RideTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  Timer? _snapshotTimer;

  late final RideEngine _engine = RideEngine(
    database: () => DatabaseHelper.instance.database,
    send: FlutterForegroundTask.sendDataToMain,
    onTrackingStart: _startTracking,
    onTrackingStop: _stopTracking,
  );

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _engine.onServiceStart();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isDestroyed) async {
    await _engine.saveSnapshot();
    await _stopTracking();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    _engine.receive(Map<String, dynamic>.from(data));
  }

  /// Otvara GPS stream i snapshot timer (idempotentno). N4: timer se pravi
  /// za svaku vožnju, ne samo pri pokretanju servisa.
  void _startTracking() {
    _positionStream ??= Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      ),
    ).listen((position) {
      _engine.onPosition(LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        timestamp: position.timestamp.toUtc(),
      ));
    }, onError: (dynamic error) {
      FlutterForegroundTask.sendDataToMain({
        'event': 'error',
        'message': 'Geolocator greška: $error',
      });
    });
    _snapshotTimer ??=
        Timer.periodic(const Duration(seconds: 10), (_) => _engine.saveSnapshot());
  }

  Future<void> _stopTracking() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    final sub = _positionStream;
    _positionStream = null;
    await sub?.cancel();
  }
}
