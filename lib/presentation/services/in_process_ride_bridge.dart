import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_foreground_task/flutter_foreground_task.dart' show DataCallback;
import 'package:geolocator/geolocator.dart';
import '../../data/database_helper.dart';
import '../../data/services/ride_engine.dart';
import '../../domain/models/location_point.dart';
import 'ride_service_controller.dart';

/// Zamena za [ForegroundBridge] na platformama bez pravog Android foreground
/// servisa (npr. iOS, lična upotreba: ekran ostaje upaljen, app u prvom
/// planu). Vozi isti [RideEngine] (nema zavisnost od plugin-a), samo bez
/// posrednog izolata — sve je u istoj niti aplikacije.
///
/// NE koristi se na Androidu; tamo [RideServiceController] i dalje dobija
/// pravi [ForegroundBridge] (pravi foreground servis), bez ikakve izmene.
class InProcessRideBridge implements ForegroundBridge {
  bool _running = false;
  StreamSubscription<Position>? _positionStream;
  Timer? _snapshotTimer;
  final List<DataCallback> _callbacks = [];

  late final RideEngine _engine = RideEngine(
    database: () => DatabaseHelper.instance.database,
    send: _send,
    onTrackingStart: _startTracking,
    onTrackingStop: _stopTracking,
  );

  @override
  Future<bool> isRunningService() async => _running;

  @override
  Future<String?> startService() async {
    _running = true;
    // Isto što RideTaskHandler.onStart radi u pravom servisu: oporavi
    // eventualnu vožnju i javi 'ready' (RideEngine to već radi samo).
    unawaited(_engine.onServiceStart());
    return null;
  }

  @override
  Future<void> stopService() async {
    await _stopTracking();
    _running = false;
  }

  @override
  void sendToTask(Map<String, dynamic> data) => _engine.receive(data);

  @override
  void addCallback(DataCallback callback) => _callbacks.add(callback);

  @override
  void removeCallback(DataCallback callback) => _callbacks.remove(callback);

  @override
  void init() {}

  void _send(Map<String, dynamic> event) {
    for (final cb in List<DataCallback>.from(_callbacks)) {
      cb(event);
    }
  }

  /// Isto što RideTaskHandler._startTracking radi, samo u glavnoj niti i sa
  /// platformski-neutralnim [LocationSettings] (bez AndroidSettings).
  void _startTracking() {
    _positionStream ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen((position) {
      if (kReleaseMode && position.isMocked) return;
      if (position.accuracy <= 0) return;
      _engine.onPosition(
        LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          timestamp: position.timestamp.toUtc(),
        ),
      );
    }, onError: (dynamic error) {
      _send({'event': 'error', 'message': 'Geolocator greška: $error'});
    });
    _snapshotTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _engine.saveSnapshot(),
    );
  }

  Future<void> _stopTracking() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    final sub = _positionStream;
    _positionStream = null;
    await sub?.cancel();
  }
}
