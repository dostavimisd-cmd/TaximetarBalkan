import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/navigation.dart';

/// Pretraga adrese (Nominatim) i predlog rute (OSRM) — oba su besplatni,
/// open source servisi nad OpenStreetMap podacima i traže internet.
///
/// Javni serveri su za malu upotrebu: Nominatim najviše 1 upit u sekundi uz
/// identifikaciju aplikacije, OSRM demo server bez garancije. Pre objave sa
/// mnogo korisnika treba sopstveni ili plaćeni server (videti KNOWN_ISSUES.md).
class NavigationService {
  NavigationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _userAgent = 'TaksimetarBalkan/1.0 (rs.taksimetar.balkan)';
  static const _timeout = Duration(seconds: 10);

  /// Pretraga adrese, sa prednošću za mesta blizu [nearLat]/[nearLon].
  Future<List<Place>> search(String query, {double? nearLat, double? nearLon}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final params = {
      'q': q,
      'format': 'jsonv2',
      'limit': '6',
      'accept-language': 'sr,en',
      if (nearLat != null && nearLon != null) ...{
        // okvir ~±0,5° oko vozača: prednost bližim rezultatima, ne isključuje dalje
        'viewbox': '${nearLon - 0.5},${nearLat + 0.5},${nearLon + 0.5},${nearLat - 0.5}',
      },
    };
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(_timeout);
    if (res.statusCode != 200) {
      throw NavigationException('Pretraga nije uspela (${res.statusCode}).');
    }
    // UTF-8 eksplicitno: bez charset-a u zaglavlju http bi dekodirao Latin-1
    // i pokvario naša slova u adresama.
    return parsePlaces(utf8.decode(res.bodyBytes));
  }

  /// Ruta za automobil od polazne do odredišne tačke.
  Future<RoutePlan> route(double fromLat, double fromLon, double toLat, double toLon) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$fromLon,$fromLat;$toLon,$toLat',
      {'overview': 'full', 'geometries': 'geojson'},
    );
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(_timeout);
    if (res.statusCode != 200) {
      throw NavigationException('Ruta nije pronađena (${res.statusCode}).');
    }
    return parseRoute(utf8.decode(res.bodyBytes));
  }

  static List<Place> parsePlaces(String body) {
    final data = jsonDecode(body);
    if (data is! List) return const [];
    final places = <Place>[];
    for (final item in data) {
      if (item is! Map) continue;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      final label = item['display_name'];
      if (lat == null || lon == null || label is! String) continue;
      places.add(Place(label: label, lat: lat, lon: lon));
    }
    return places;
  }

  static RoutePlan parseRoute(String body) {
    final data = jsonDecode(body);
    if (data is! Map || data['code'] != 'Ok') {
      throw const NavigationException('Ruta nije pronađena.');
    }
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const NavigationException('Ruta nije pronađena.');
    }
    final r = routes.first as Map;
    final coords = (r['geometry'] as Map)['coordinates'] as List;
    return RoutePlan(
      // GeoJSON je [lon, lat]
      points: [
        for (final c in coords.cast<List>())
          ((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ],
      distanceMeters: (r['distance'] as num).round(),
      durationSeconds: (r['duration'] as num).round(),
    );
  }
}

class NavigationException implements Exception {
  final String message;
  const NavigationException(this.message);

  @override
  String toString() => message;
}
