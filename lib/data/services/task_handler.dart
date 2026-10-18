import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/models/location_point.dart';
import '../../domain/models/tariff.dart';
import '../../domain/ride_tracker.dart';
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

  // Prilagođeno novom potpisu: TaskStarter umesto SendPort
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      if (tracker != null) {
        final point = LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          timestamp: position.timestamp,
        );
        
        tracker!.processLocation(point);
        
        // Novo slanje podataka u Main Isolate
        FlutterForegroundTask.sendDataToMain({
          'event': 'update',
          'distance': tracker!.totalDistanceMeters,
          'waitingMs': tracker!.totalWaitingMs,
          'price': tracker!.currentFare?.totalPrice ?? tracker!.tariff.startPrice,
        });
      }
    });

    _snapshotTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveSnapshot());
  }

  // Prilagođeno novom potpisu: void umesto Future<void>
  @override
  void onRepeatEvent(DateTime timestamp) {}

  // Prilagođeno novom potpisu: bool isDestroyed umesto SendPort
  @override
  Future<void> onDestroy(DateTime timestamp, bool isDestroyed) async {
    await _positionStream?.cancel();
    _snapshotTimer?.cancel();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      if (data['command'] == 'start') {
        final tariff = Tariff(
          id: data['tariff_id'] ?? 1,
          startPrice: data['start_price'],
          pricePerKm: data['price_per_km'],
          waitingPricePerMin: data['waiting_price_per_min'],
          minPrice: data['min_price']
        );
        currentRideId = data['ride_id'];
        tracker = RideTracker(
          tariff: tariff, 
          // Pazimo da cast-ujemo u double ako stigne kao int (čest JSON problem)
          calibrationMultiplier: (data['calibration'] as num?)?.toDouble() ?? 1.0,
        );
      } else if (data['command'] == 'stop') {
        FlutterForegroundTask.stopService();
      }
    }
  }

  Future<void> _saveSnapshot() async {
    if (tracker == null || currentRideId == null || tracker!.lastValidPoint == null) return;
    
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('ride_snapshots'); 
        await txn.insert('ride_snapshots', {
          'ride_id': currentRideId,
          'current_distance': tracker!.totalDistanceMeters,
          'current_waiting_ms': tracker!.totalWaitingMs,
          'current_price': tracker!.currentFare?.totalPrice ?? tracker!.tariff.startPrice,
          'last_lat': tracker!.lastValidPoint!.latitude,
          'last_lon': tracker!.lastValidPoint!.longitude,
          'timestamp': tracker!.lastValidPoint!.timestamp.millisecondsSinceEpoch,
        });
      });
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({
        'event': 'error',
        'message': 'Greška pri upisu snapshota: $e'
      });
    }
  }
}