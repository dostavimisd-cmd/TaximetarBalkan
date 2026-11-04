import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
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

/// Dugmad u obaveštenju posle događaja iz servisa; null = bez promene.
/// Id dugmeta je komanda za [RideEngine] (`pause`, `resume`, `stop`).
List<NotificationButton>? rideNotificationButtons(
  Map<String, dynamic> event, {
  required bool english,
}) {
  final pause = NotificationButton(id: 'pause', text: english ? 'PAUSE' : 'PAUZA');
  final resume = NotificationButton(id: 'resume', text: english ? 'RESUME' : 'NASTAVI');
  final stop = NotificationButton(id: 'stop', text: english ? 'END' : 'ZAVRŠI');
  switch (event['event']) {
    case 'started':
    case 'resumed':
      return [pause, stop];
    case 'recovered':
      return event['paused'] == true ? [resume, stop] : [pause, stop];
    case 'paused':
      return [resume, stop];
    case 'stopped':
      return const [];
  }
  return null;
}

/// Lepak između plugin-a i [RideEngine]: prosleđuje komande i GPS tačke,
/// a GPS stream i snapshot timer drži otvorenim samo dok traje vožnja.
/// Dugmad u obaveštenju (pauza, nastavak, kraj) šalju iste komande kao UI.
class RideTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  Timer? _snapshotTimer;
  bool _stopFromNotification = false;

  late final RideEngine _engine = RideEngine(
    database: () => DatabaseHelper.instance.database,
    send: _onEngineEvent,
    onTrackingStart: _startTracking,
    onTrackingStop: _stopTracking,
  );

  void _onEngineEvent(Map<String, dynamic> event) {
    FlutterForegroundTask.sendDataToMain(event);
    unawaited(_updateButtons(event));
    // Stop nije upisan (vožnja i dalje traje): servis ne sme sam da se ugasi.
    if (event['event'] == 'error' && event['cmd'] == 'stop') {
      _stopFromNotification = false;
    }
    if (event['event'] == 'stopped' && _stopFromNotification) {
      _stopFromNotification = false;
      // Servis gasi UI (kontroler). Ako je aplikacija zatvorena, niko ga ne
      // gasi, pa to radimo sami posle kratkog čekanja; ako ga UI ugasi pre
      // toga, ovaj izolat više ne postoji i tajmer se ne izvršava.
      Timer(const Duration(seconds: 3), FlutterForegroundTask.stopService);
    }
  }

  Future<void> _updateButtons(Map<String, dynamic> event) async {
    try {
      final english = await _isEnglish();
      final buttons = rideNotificationButtons(event, english: english);
      if (buttons == null) return;
      await FlutterForegroundTask.updateService(notificationButtons: buttons);
    } catch (_) {
      // Obaveštenje bez dugmadi ne sme da utiče na vožnju.
    }
  }

  Future<bool> _isEnglish() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['language'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == 'en';
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id != 'pause' && id != 'resume' && id != 'stop') return;
    if (id == 'stop') _stopFromNotification = true;
    _engine.receive({'command': id});
  }

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
      // U6: lažne lokacije samo u debug build-u (emulator); accuracy 0 znači
      // da uređaj nije dao preciznost, pa se tačka ne može proveriti.
      if (kReleaseMode && position.isMocked) return;
      if (position.accuracy <= 0) return;
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
