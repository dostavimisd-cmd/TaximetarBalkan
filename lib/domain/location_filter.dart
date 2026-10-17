import 'dart:math';
import 'models/location_point.dart';

class LocationFilter {
  final double accuracyThresholdMeters;
  final double maxSpeedKmh;

  LocationFilter({
    this.accuracyThresholdMeters = 15.0,
    this.maxSpeedKmh = 200.0, // Preko ovoga smatramo da je "skok" (GPS greška)
  });

  bool isValid(LocationPoint newPoint, LocationPoint? lastPoint) {
    if (newPoint.accuracy > accuracyThresholdMeters) return false;

    if (lastPoint != null) {
      final secondsPassed = newPoint.timestamp.difference(lastPoint.timestamp).inSeconds;
      if (secondsPassed <= 0) return false;

      final distance = _calculateDistance(
        lastPoint.latitude, lastPoint.longitude,
        newPoint.latitude, newPoint.longitude,
      );
      final speed = (distance / secondsPassed) * 3.6;

      if (speed > maxSpeedKmh) return false; // Nerealan skok
    }
    return true;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}