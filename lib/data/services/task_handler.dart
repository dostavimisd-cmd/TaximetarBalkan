import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/models/location_point.dart';
import '../../domain/models/tariff.dart';
import '../../domain/ride_tracker.dart';
import '../../domain/fare_calculator.dart';
import '../database_helper.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RideTaskHandler());
}

class RideTaskHandler extends TaskHandler {
  RideTracker? tracker;
  StreamSubscription<Position>? _positionStream;
  Timer? _snapshotTimer;
  int? currentRideId;
  int _snapshotFailures = 0;

  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusInterrupted = 'interrupted';

  // Oporavak dozvoljen samo ako je snapshot mlađi od 5 minuta
  static const int maxSnapshotAgeMs = 5 * 60 * 1000;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _recoverActiveRide();

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (tracker != null) {
        try {
          final point = LocationPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            speed: position.speed,
            timestamp: position.timestamp.toUtc(),
          );

          tracker!.processLocation(point);

          FlutterForegroundTask.sendDataToMain({
            'event': 'update',
            'distance': tracker!.totalDistanceMeters,
            'waitingMs': tracker!.totalWaitingMs,
            'price': tracker!.currentFare?.totalPrice ?? tracker!.tariff.startPrice,
          });
        } catch (e) {
          FlutterForegroundTask.sendDataToMain({
            'event': 'error',
            'message': 'Greška pri obradi GPS tačke: $e'
          });
        }
      }
    }, onError: (dynamic error) {
      FlutterForegroundTask.sendDataToMain({
        'event': 'error',
        'message': 'Geolocator greška: $error'
      });
    });

    _snapshotTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveSnapshot());
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isDestroyed) async {
    await _saveSnapshot(); // Poslednji pokušaj čuvanja (ne radi ništa ako je vožnja završena)
    await _positionStream?.cancel();
    _snapshotTimer?.cancel();
  }

  @override
  void onReceiveData(Object data) async {
    if (data is Map) {
      final mapData = Map<String, dynamic>.from(data);
      if (mapData['command'] == 'start') {
        await _handleStartCommand(mapData);
      } else if (mapData['command'] == 'stop') {
        await _handleStopCommand();
      }
    }
  }

  Future<void> _handleStartCommand(Map<String, dynamic> data) async {
    if (tracker != null || currentRideId != null) {
      FlutterForegroundTask.sendDataToMain({'event': 'already_active'});
      return;
    }

    final requiredKeys = [
      'tariff_id',
      'start_price',
      'price_per_km',
      'waiting_price_per_min',
      'min_price'
    ];
    for (final key in requiredKeys) {
      if (!data.containsKey(key) || data[key] == null) {
        FlutterForegroundTask.sendDataToMain({
          'event': 'error',
          'message': 'Nedostaje obavezno polje tarife: $key'
        });
        return;
      }
    }

    try {
      final tariff = Tariff(
        id: data['tariff_id'] as int,
        startPrice: data['start_price'] as int,
        pricePerKm: data['price_per_km'] as int,
        waitingPricePerMin: data['waiting_price_per_min'] as int,
        minPrice: data['min_price'] as int,
      );
      final calibration = (data['calibration'] as num?)?.toDouble() ?? 1.0;

      final db = await DatabaseHelper.instance.database;
      await _cleanupOldActiveRides();

      final rideId = await db.insert('rides', {
        'start_time': DateTime.now().millisecondsSinceEpoch,
        'distance_m': 0,
        'waiting_time_sec': 0,
        'start_price': tariff.startPrice,
        'km_price': 0,
        'waiting_price': 0,
        'total_price': tariff.startPrice,
        'tariff_id': tariff.id,
        'applied_calibration': calibration,
        'status': statusActive,
        'tariff_start_price': tariff.startPrice,
        'tariff_price_per_km': tariff.pricePerKm,
        'tariff_waiting_price_per_min': tariff.waitingPricePerMin,
        'tariff_min_price': tariff.minPrice,
        'min_price_adjustment': 0,
      });

      currentRideId = rideId;
      tracker = RideTracker(tariff: tariff, calibrationMultiplier: calibration);
      _snapshotFailures = 0;

      FlutterForegroundTask.sendDataToMain({
        'event': 'started',
        'ride_id': currentRideId,
      });
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({
        'event': 'error',
        'message': 'Greška pri kreiranju vožnje: $e'
      });
    }
  }

  Future<void> _handleStopCommand() async {
    if (currentRideId != null && tracker != null) {
      _snapshotTimer?.cancel(); // Otkazujemo timer pre upisa

      try {
        final db = await DatabaseHelper.instance.database;

        final finalFare = FareCalculator.calculate(
          tariff: tracker!.tariff,
          distanceMeters: tracker!.totalDistanceMeters.round(),
          waitingSeconds: tracker!.totalWaitingMs ~/ 1000,
          calibrationMultiplier: tracker!.calibrationMultiplier,
        );

        await db.update('rides', {
          'end_time': DateTime.now().millisecondsSinceEpoch,
          'status': statusCompleted,
          'distance_m': tracker!.totalDistanceMeters.round(),
          'waiting_time_sec': tracker!.totalWaitingMs ~/ 1000,
          'km_price': finalFare.kmPrice,
          'waiting_price': finalFare.waitingPrice,
          'total_price': finalFare.totalPrice,
          'min_price_adjustment': finalFare.minPriceAdjustment,
        }, where: 'id = ?', whereArgs: [currentRideId]);

        await db.delete('ride_snapshots',
            where: 'ride_id = ?', whereArgs: [currentRideId]);

        FlutterForegroundTask.sendDataToMain({'event': 'stopped'});
      } catch (e) {
        FlutterForegroundTask.sendDataToMain({
          'event': 'error',
          'message': 'Greška pri zatvaranju vožnje: $e'
        });
      }
    }

    // Čistimo stanje da onDestroy ne upiše snapshot za završenu vožnju
    tracker = null;
    currentRideId = null;
    FlutterForegroundTask.stopService();
  }

  Future<void> _saveSnapshot() async {
    if (tracker == null || currentRideId == null || tracker!.lastValidPoint == null) {
      return;
    }
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('ride_snapshots',
            where: 'ride_id = ?', whereArgs: [currentRideId]);
        await txn.insert('ride_snapshots', {
          'ride_id': currentRideId,
          'current_distance': tracker!.totalDistanceMeters,
          'current_waiting_ms': tracker!.totalWaitingMs,
          'current_price':
              tracker!.currentFare?.totalPrice ?? tracker!.tariff.startPrice,
          'last_lat': tracker!.lastValidPoint!.latitude,
          'last_lon': tracker!.lastValidPoint!.longitude,
          'timestamp':
              tracker!.lastValidPoint!.timestamp.millisecondsSinceEpoch,
        });
      });
      _snapshotFailures = 0;
    } catch (e) {
      _snapshotFailures++;
      if (_snapshotFailures == 3) {
        FlutterForegroundTask.sendDataToMain({
          'event': 'snapshot_failing',
          'message': 'Vožnja se ne snima u bazu: $e'
        });
      }
    }
  }

  Future<void> _cleanupOldActiveRides() async {
    final db = await DatabaseHelper.instance.database;
    final oldRides =
        await db.query('rides', where: 'status = ?', whereArgs: [statusActive]);

    for (final ride in oldRides) {
      final rideId = ride['id'] as int;
      final snaps = await db.query('ride_snapshots',
          where: 'ride_id = ?',
          whereArgs: [rideId],
          orderBy: 'id DESC',
          limit: 1);

      int endTime = ride['start_time'] as int;
      if (snaps.isNotEmpty) {
        endTime = snaps.first['timestamp'] as int;
      }

      await db.update('rides', {
        'status': statusInterrupted,
        'end_time': endTime,
      }, where: 'id = ?', whereArgs: [rideId]);
    }
  }

  Future<void> _recoverActiveRide() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rides = await db.query('rides',
          where: 'status = ?',
          whereArgs: [statusActive],
          orderBy: 'id DESC',
          limit: 1);

      if (rides.isNotEmpty) {
        final ride = rides.first;
        final rId = ride['id'] as int;

        final snaps = await db.query('ride_snapshots',
            where: 'ride_id = ?',
            whereArgs: [rId],
            orderBy: 'id DESC',
            limit: 1);

        // Napomena: ako vožnja nema snapshot (servis pao u prvih ~10 s),
        // ne oporavlja se; sledeći start je označava kao 'interrupted'.
        if (snaps.isNotEmpty) {
          final snap = snaps.first;
          final snapTime = snap['timestamp'] as int;

          if (DateTime.now().millisecondsSinceEpoch - snapTime >
              maxSnapshotAgeMs) {
            await db.update('rides',
                {'status': statusInterrupted, 'end_time': snapTime},
                where: 'id = ?', whereArgs: [rId]);
            return;
          }

          currentRideId = rId;
          final tariff = Tariff(
            id: ride['tariff_id'] as int,
            startPrice: ride['tariff_start_price'] as int,
            pricePerKm: ride['tariff_price_per_km'] as int,
            waitingPricePerMin: ride['tariff_waiting_price_per_min'] as int,
            minPrice: ride['tariff_min_price'] as int,
          );

          tracker = RideTracker(
            tariff: tariff,
            calibrationMultiplier:
                (ride['applied_calibration'] as num).toDouble(),
          );

          tracker!.restoreFromSnapshot(
            restoredDistance: (snap['current_distance'] as num).toDouble(),
            restoredWaitingMs: snap['current_waiting_ms'] as int,
            lastLat: (snap['last_lat'] as num).toDouble(),
            lastLon: (snap['last_lon'] as num).toDouble(),
            lastTimestamp:
                DateTime.fromMillisecondsSinceEpoch(snapTime, isUtc: true),
          );

          FlutterForegroundTask.sendDataToMain({
            'event': 'recovered',
            'ride_id': currentRideId,
            'distance': tracker!.totalDistanceMeters,
            'waitingMs': tracker!.totalWaitingMs,
            'price': tracker!.currentFare?.totalPrice ?? tariff.startPrice,
          });
        }
      }
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({
        'event': 'error',
        'message': 'Greška pri oporavku vožnje: $e'
      });
    }
  }
}