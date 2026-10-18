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

  final Tariff tariff;
  final double calibrationMultiplier;
  final LocationFilter filter;
  final SmartWaiter waiter;

  RideTracker({
    required this.tariff,
    this.calibrationMultiplier = 1.0,
    this.filter = const LocationFilter(),
    this.waiter = const SmartWaiter(),
  });

  LocationPoint? get lastValidPoint => _lastValidPoint;

  void processLocation(LocationPoint newPoint) {
    if (!filter.isValid(newPoint, _lastValidPoint)) return;

    if (_lastValidPoint != null) {
      final result = waiter.process(_lastValidPoint!, newPoint);
      totalDistanceMeters += result.addedDistanceMeters;
      totalWaitingMs += result.addedWaitingMs;
    }

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
}