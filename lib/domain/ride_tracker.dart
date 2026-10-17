import 'dart:math';
import 'models/location_point.dart';

class RideTracker {
  final double accuracyThresholdMeters;
  final double waitingSpeedThresholdKmh;

  int totalDistanceMeters = 0;
  int totalWaitingSeconds = 0;

  LocationPoint? _lastValidPoint;

  RideTracker({
    this.accuracyThresholdMeters = 15.0,
    this.waitingSpeedThresholdKmh = 8.0,
  });

  /// Haversine formula za računanje vazdušne distance u metrima (čist Dart, bez zavisnosti)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000; // Poluprečnik Zemlje u metrima
    final double dLat = (lat2 - lat1) * (pi / 180.0);
    final double dLon = (lon2 - lon1) * (pi / 180.0);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Obrađuje novu GPS tačku, filtrira šum i računa distancu/čekanje
  void processLocation(LocationPoint newPoint) {
    // 1. Filtriranje GPS šuma
    if (newPoint.accuracy > accuracyThresholdMeters) {
      return; 
    }

    if (_lastValidPoint != null) {
      final int secondsPassed = newPoint.timestamp.difference(_lastValidPoint!.timestamp).inSeconds;
      
      // Ignorišemo tačke sa istim vremenom
      if (secondsPassed <= 0) return;

      final double distance = _calculateDistance(
        _lastValidPoint!.latitude,
        _lastValidPoint!.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );

      final double speedKmh = (distance / secondsPassed) * 3.6;

      // 2. Pametno čekanje (ako je brzina ispod praga, sabiramo vreme umesto distance)
      if (speedKmh < waitingSpeedThresholdKmh) {
        totalWaitingSeconds += secondsPassed;
      } else {
        totalDistanceMeters += distance.round();
      }
    }

    _lastValidPoint = newPoint;
  }
}