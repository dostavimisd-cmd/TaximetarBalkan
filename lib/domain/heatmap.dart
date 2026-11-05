import 'location_filter.dart';

/// Početak vožnje za toplotnu mapu: mesto (prva tačka rute) i lokalno vreme.
class RideStart {
  final double lat;
  final double lon;
  final DateTime local;
  const RideStart(this.lat, this.lon, this.local);
}

/// Jedna zona (~250 m) i broj vožnji koje su u njoj počele.
class HeatCell {
  final double lat; // prosek početaka u ćeliji
  final double lon;
  final int count;
  const HeatCell(this.lat, this.lon, this.count);
}

/// Deo dana za filter: od–do sat (lokalno, kraj nije uključen).
enum DayPart {
  all(0, 24),
  morning(6, 12),
  afternoon(12, 18),
  evening(18, 24),
  night(0, 6);

  const DayPart(this.from, this.to);
  final int from;
  final int to;

  bool contains(int hour) => hour >= from && hour < to;
}

/// Toplotna mapa iz sopstvene istorije (G7): grupisanje početaka vožnji u
/// zone, sa filterom po danu u nedelji i delu dana. Čist Dart.
class Heatmap {
  /// Poluprečnik zone u metrima: početak ide u zonu čiji je centar bliži od ovoga.
  static const double cellMeters = 250;

  /// [weekdays] = DateTime.monday … DateTime.sunday; prazno = svi dani.
  /// Grupisanje po razdaljini (ne fiksna mreža), pa dve bliske tačke ne
  /// završe u susednim ćelijama.
  static List<HeatCell> cells(
    Iterable<RideStart> starts, {
    Set<int> weekdays = const {},
    DayPart part = DayPart.all,
  }) {
    final zones = <_Zone>[];
    for (final s in starts) {
      if (weekdays.isNotEmpty && !weekdays.contains(s.local.weekday)) continue;
      if (!part.contains(s.local.hour)) continue;
      final zone = zones
          .where((z) => LocationFilter.calculateDistance(z.lat, z.lon, s.lat, s.lon) < cellMeters)
          .firstOrNull;
      if (zone == null) {
        zones.add(_Zone()..addPoint(s.lat, s.lon));
      } else {
        zone.addPoint(s.lat, s.lon);
      }
    }
    return [for (final z in zones) HeatCell(z.lat, z.lon, z.count)]
      ..sort((a, b) => b.count.compareTo(a.count));
  }
}

class _Zone {
  double _sumLat = 0, _sumLon = 0;
  int count = 0;
  double get lat => _sumLat / count;
  double get lon => _sumLon / count;
  void addPoint(double lat, double lon) {
    _sumLat += lat;
    _sumLon += lon;
    count++;
  }
}
