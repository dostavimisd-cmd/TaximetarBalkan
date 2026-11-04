import 'location_filter.dart';
import 'models/navigation.dart';

/// Pomoć za pretragu adrese: upit, prikaz latinicom i redosled po blizini.
/// Čist Dart (bez mreže), da se testira bez servera.
class PlaceSearch {
  static const Map<String, String> _cyrToLat = {
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Ђ': 'Đ', 'Е': 'E',
    'Ж': 'Ž', 'З': 'Z', 'И': 'I', 'Ј': 'J', 'К': 'K', 'Л': 'L', 'Љ': 'Lj',
    'М': 'M', 'Н': 'N', 'Њ': 'Nj', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S',
    'Т': 'T', 'Ћ': 'Ć', 'У': 'U', 'Ф': 'F', 'Х': 'H', 'Ц': 'C', 'Ч': 'Č',
    'Џ': 'Dž', 'Ш': 'Š',
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'ђ': 'đ', 'е': 'e',
    'ж': 'ž', 'з': 'z', 'и': 'i', 'ј': 'j', 'к': 'k', 'л': 'l', 'љ': 'lj',
    'м': 'm', 'н': 'n', 'њ': 'nj', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's',
    'т': 't', 'ћ': 'ć', 'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'c', 'ч': 'č',
    'џ': 'dž', 'ш': 'š',
  };

  /// Srpska ćirilica u latinicu (podaci OSM-a u Srbiji su ćirilicom).
  /// „ЉУБЕ” → „LJUBE”: dvoslovna slova u reči od velikih slova ostaju velika.
  static String toLatin(String text) {
    final out = StringBuffer();
    final chars = text.split('');
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      var l = _cyrToLat[c];
      if (l == null) {
        out.write(c);
        continue;
      }
      if (l.length == 2 && l[0] != l[0].toLowerCase()) {
        final next = i + 1 < chars.length ? chars[i + 1] : '';
        final prev = i > 0 ? chars[i - 1] : '';
        bool upper(String s) => s.isNotEmpty && s != s.toLowerCase();
        if (upper(next) || (next.isEmpty || next == ' ') && upper(prev)) {
          l = l.toUpperCase();
        }
      }
      out.write(l);
    }
    return out.toString();
  }

  /// Upit za server: „đ” se piše „dj” (tako se nalaze i ulice zapisane
  /// ćirilicom); ostala slova servis sam poravnava.
  static String normalizeQuery(String query) => query
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('đ', 'dj')
      .replaceAll('Đ', 'Dj');

  /// Prvo najbliže vozaču (ulice u mestu, pa okolna sela, pa drugi gradovi);
  /// bez lokacije ostaje redosled servera. Dupli (isti naziv, blizu) se izbacuju.
  static List<Place> rank(
    List<Place> places, {
    double? nearLat,
    double? nearLon,
    int limit = 8,
  }) {
    final withDistance = [
      for (final p in places)
        nearLat == null || nearLon == null
            ? p
            : p.withDistance(
                LocationFilter.calculateDistance(nearLat, nearLon, p.lat, p.lon)
                    .round(),
              ),
    ];
    if (nearLat != null && nearLon != null) {
      // stabilno: isti razmak zadržava redosled servera
      final indexed = withDistance.indexed.toList()
        ..sort((a, b) {
          final d = a.$2.distanceMeters!.compareTo(b.$2.distanceMeters!);
          return d != 0 ? d : a.$1.compareTo(b.$1);
        });
      withDistance
        ..clear()
        ..addAll(indexed.map((e) => e.$2));
    }
    final result = <Place>[];
    for (final p in withDistance) {
      final duplicate = result.any((r) =>
          r.label == p.label &&
          LocationFilter.calculateDistance(r.lat, r.lon, p.lat, p.lon) < 1500);
      if (!duplicate) result.add(p);
      if (result.length == limit) break;
    }
    return result;
  }

  /// „850 m” ili „12,4 km”.
  static String formatDistance(int meters) {
    if (meters < 1000) return '${(meters / 10).round() * 10} m';
    final tenths = (meters / 100).round();
    return '${tenths ~/ 10},${tenths % 10} km';
  }
}
