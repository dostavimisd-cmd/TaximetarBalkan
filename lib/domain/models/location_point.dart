class LocationPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}