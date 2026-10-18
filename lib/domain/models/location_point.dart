class LocationPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed; 
  final DateTime timestamp;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.timestamp,
  });
}