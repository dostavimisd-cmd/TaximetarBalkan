import 'dart:math';
import 'models/location_point.dart';

class LocationFilter {
  final double accuracyThresholdMeters;
  final double maxSpeedKmh;
  final int resetGapSeconds;

  const LocationFilter({
    this.accuracyThresholdMeters = 15.0,
    this.maxSpeedKmh = 200.0,
    this.resetGapSeconds = 60,
  });

  bool isValid(LocationPoint newPoint, LocationPoint? lastPoint) {
    if (newPoint.accuracy > accuracyThresholdMeters) return false;
    if (lastPoint == null) return true;

    final msPassed = newPoint.timestamp.difference(lastPoint.timestamp).inMilliseconds;
    if (msPassed <= 0) return false;

    final distance = calculateDistance(
      lastPoint.latitude, lastPoint.longitude,
      newPoint.latitude, newPoint.longitude,
    );
    final calculatedSpeedKmh = (distance / (msPassed / 1000.0)) * 3.6;

    if (calculatedSpeedKmh > maxSpeedKmh) {
      if ((msPassed / 1000.0) < resetGapSeconds) {
        return false; 
      }
      return true; 
    }

    return true;
  }

  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000.0;
    final double dLat = (lat2 - lat1) * (pi / 180.0);
    final double dLon = (lon2 - lon1) * (pi / 180.0);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * asin(sqrt(a));
  }
}