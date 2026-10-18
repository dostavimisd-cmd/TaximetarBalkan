import 'location_filter.dart';
import 'models/location_point.dart';

class SmartWaiterResult {
  final double addedDistanceMeters;
  final int addedWaitingMs;

  const SmartWaiterResult(this.addedDistanceMeters, this.addedWaitingMs);
}

class SmartWaiter {
  final double waitingSpeedThresholdKmh;

  /// Dužina prozora za procenu brzine (ms). Brzina se meri na ovom prozoru,
  /// ne između dve susedne tačke, da bi GPS šum dok vozilo stoji ostao ispod praga.
  final int windowMs;

  const SmartWaiter({
    this.waitingSpeedThresholdKmh = 8.0,
    this.windowMs = 5000,
  });

  /// [windowStart] je poslednja validna tačka stara bar [windowMs] (daje je RideTracker).
  /// Ako je null, brzina se računa između lastPoint i newPoint.
  SmartWaiterResult process(
    LocationPoint lastPoint,
    LocationPoint newPoint, {
    LocationPoint? windowStart,
  }) {
    final msPassed =
        newPoint.timestamp.difference(lastPoint.timestamp).inMilliseconds;
    if (msPassed <= 0) return const SmartWaiterResult(0.0, 0);

    final distance = LocationFilter.calculateDistance(
      lastPoint.latitude, lastPoint.longitude,
      newPoint.latitude, newPoint.longitude,
    );

    // Brzina iz pomaka na prozoru (GPS speed se ne koristi za odluku).
    final ref = windowStart ?? lastPoint;
    final refMs = newPoint.timestamp.difference(ref.timestamp).inMilliseconds;
    final refDistance = identical(ref, lastPoint)
        ? distance
        : LocationFilter.calculateDistance(
            ref.latitude, ref.longitude,
            newPoint.latitude, newPoint.longitude,
          );

    final double speedKmh = refMs > 0
        ? (refDistance / (refMs / 1000.0)) * 3.6
        : newPoint.speed * 3.6; // samo ako nema upotrebljivog prozora

    if (speedKmh < waitingSpeedThresholdKmh) {
      return SmartWaiterResult(0.0, msPassed);
    }
    return SmartWaiterResult(distance, 0);
  }
}