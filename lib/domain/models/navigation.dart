/// Mesto pronađeno pretragom adrese.
class Place {
  final String label;
  final double lat;
  final double lon;

  /// Vazdušna udaljenost od vozača (m); null kad lokacija nije poznata.
  final int? distanceMeters;

  const Place({
    required this.label,
    required this.lat,
    required this.lon,
    this.distanceMeters,
  });

  Place withDistance(int meters) =>
      Place(label: label, lat: lat, lon: lon, distanceMeters: meters);

  /// Ista adresa (omiljene): isti natpis i tačka na ~10 m.
  bool sameAs(Place o) =>
      o.label == label && (o.lat - lat).abs() < 1e-4 && (o.lon - lon).abs() < 1e-4;

  Map<String, Object> toJson() => {'label': label, 'lat': lat, 'lon': lon};

  static Place? fromJson(Object? o) {
    if (o is! Map) return null;
    final label = o['label'], lat = o['lat'], lon = o['lon'];
    if (label is! String || label.trim().isEmpty || lat is! num || lon is! num) {
      return null;
    }
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    return Place(label: label, lat: lat.toDouble(), lon: lon.toDouble());
  }
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
