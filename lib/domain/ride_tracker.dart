import 'models/location_point.dart';
import 'models/tariff.dart';
import 'models/fare_result.dart';
import 'location_filter.dart';
import 'smart_waiter.dart';
import 'fare_calculator.dart';

class RideTracker {
  double totalDistanceMeters = 0.0;
  int totalWaitingMs = 0;
  FareResult? currentFare;
  LocationPoint? _lastValidPoint;
  
  final List<LocationPoint> _recentPoints = [];
  final int windowMs;

  final Tariff tariff;
  final double calibrationMultiplier;
  final LocationFilter filter;
  final SmartWaiter waiter;

  RideTracker({
    required this.tariff,
    this.calibrationMultiplier = 1.0,
    this.filter = const LocationFilter(),
    this.waiter = const SmartWaiter(),
    this.windowMs = 4000, // 4 sekunde prozor
  });

  LocationPoint? get lastValidPoint => _lastValidPoint;

  void processLocation(LocationPoint newPoint) {
    if (!filter.isValid(newPoint, _lastValidPoint)) return;

    if (_lastValidPoint != null) {
      final msPassed = newPoint.timestamp.difference(_lastValidPoint!.timestamp).inMilliseconds;
      final distance = LocationFilter.calculateDistance(
        _lastValidPoint!.latitude, _lastValidPoint!.longitude,
        newPoint.latitude, newPoint.longitude,
      );
      final calculatedSpeedKmh = (distance / (msPassed / 1000.0)) * 3.6;

      if (calculatedSpeedKmh > filter.maxSpeedKmh && (msPassed / 1000.0) >= filter.resetGapSeconds) {
        // Reset tačka - praznimo istoriju
        _recentPoints.clear();
      } else {
        // Tražimo windowStart (najnoviju tačku koja je stara bar windowMs)
        LocationPoint windowStart = _lastValidPoint!;
        for (int i = _recentPoints.length - 1; i >= 0; i--) {
          if (newPoint.timestamp.difference(_recentPoints[i].timestamp).inMilliseconds >= windowMs) {
            windowStart = _recentPoints[i];
            break;
          }
        }
        // Ako nema takve (početak vožnje), uzimamo najstariju dostupnu
        if (windowStart == _lastValidPoint && _recentPoints.isNotEmpty) {
          if (newPoint.timestamp.difference(_recentPoints.first.timestamp).inMilliseconds < windowMs) {
            windowStart = _recentPoints.first;
          }
        }

        final result = waiter.process(_lastValidPoint!, newPoint, windowStart);
        totalDistanceMeters += result.addedDistanceMeters;
        totalWaitingMs += result.addedWaitingMs;
      }
    }

    _recentPoints.add(newPoint);
    // Čistimo stare tačke (čuvamo windowMs + malo lufta)
    _recentPoints.removeWhere((p) => newPoint.timestamp.difference(p.timestamp).inMilliseconds > windowMs + 2000);

    _lastValidPoint = newPoint;
    _recalculateFare();
  }

  void _recalculateFare() {
    currentFare = FareCalculator.calculate(
      tariff: tariff,
      distanceMeters: totalDistanceMeters.round(),
      waitingSeconds: totalWaitingMs ~/ 1000,
      calibrationMultiplier: calibrationMultiplier,
    );
  }

  /// Sledeća tačka postaje polazna (bez distance i čekanja do nje).
  /// Zbirovi i cena ostaju.
  void dropLastPoint() {
    _lastValidPoint = null;
    _recentPoints.clear();
  }

  void restoreFromSnapshot({
    required double restoredDistance,
    required int restoredWaitingMs,
    required double lastLat,
    required double lastLon,
    required DateTime lastTimestamp,
  }) {
    totalDistanceMeters = restoredDistance;
    totalWaitingMs = restoredWaitingMs;
    _lastValidPoint = LocationPoint(
      latitude: lastLat, 
      longitude: lastLon, 
      accuracy: 0.0, 
      speed: 0.0, 
      timestamp: lastTimestamp
    );
    _recentPoints.clear();
    _recentPoints.add(_lastValidPoint!);
    _recalculateFare();
  }
}