import 'location_filter.dart';
import 'models/location_point.dart';

class SmartWaiterResult {
  final double addedDistanceMeters;
  final int addedWaitingMs;
  
  const SmartWaiterResult(this.addedDistanceMeters, this.addedWaitingMs);
}

class SmartWaiter {
  final double waitingSpeedThresholdKmh;
  final int gapThresholdMs;

  const SmartWaiter({
    this.waitingSpeedThresholdKmh = 8.0,
    this.gapThresholdMs = 10000, 
  });

  SmartWaiterResult process(
    LocationPoint lastPoint, 
    LocationPoint newPoint, 
    LocationPoint windowStart,
  ) {
    final msPassed = newPoint.timestamp.difference(lastPoint.timestamp).inMilliseconds;
    if (msPassed <= 0) return const SmartWaiterResult(0.0, 0);

    // Stvarna pređena distanca od prošle tačke (za sabiranje ako vozimo)
    final stepDistance = LocationFilter.calculateDistance(
      lastPoint.latitude, lastPoint.longitude,
      newPoint.latitude, newPoint.longitude,
    );

    double effectiveSpeedKmh = newPoint.speed * 3.6;

    final windowMs = newPoint.timestamp.difference(windowStart.timestamp).inMilliseconds;
    
    // Ako GPS kaže 0 ili imamo rupu, koristimo prozor za izračunavanje brzine
    if (msPassed > gapThresholdMs || newPoint.speed <= 0.01) {
      if (windowMs > 0) {
        final windowDistance = LocationFilter.calculateDistance(
          windowStart.latitude, windowStart.longitude,
          newPoint.latitude, newPoint.longitude,
        );
        effectiveSpeedKmh = (windowDistance / (windowMs / 1000.0)) * 3.6;
      } else {
        effectiveSpeedKmh = (stepDistance / (msPassed / 1000.0)) * 3.6;
      }
    }

    // Klasifikacija: stoji ili vozi na osnovu brzine iz prozora
    if (effectiveSpeedKmh < waitingSpeedThresholdKmh) {
      return SmartWaiterResult(0.0, msPassed);
    } else {
      return SmartWaiterResult(stepDistance, 0);
    }
  }
}