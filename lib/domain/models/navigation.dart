/// Mesto pronađeno pretragom adrese.
class Place {
  final String label;
  final double lat;
  final double lon;

  const Place({required this.label, required this.lat, required this.lon});
}

/// Predlog rute do odredišta (samo za orijentaciju vozača; ne utiče na
/// obračun, koji se uvek računa iz stvarno pređenog puta).
class RoutePlan {
  final List<(double lat, double lon)> points;
  final int distanceMeters;
  final int durationSeconds;

  const RoutePlan({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String describe() {
    final km = (distanceMeters / 1000).toStringAsFixed(1);
    final min = (durationSeconds / 60).round();
    return '$km km · ~$min min';
  }
}
