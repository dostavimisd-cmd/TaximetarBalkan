import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/navigation.dart';
import '../../domain/place_search.dart';

/// Pretraga adrese dok se kuca (Photon), rezerva Nominatim, i predlog rute
/// (OSRM) — besplatni, open source servisi nad OpenStreetMap podacima; traže
/// internet.
///
/// Javni serveri su za malu upotrebu: Photon (komoot) bez garancije, Nominatim
/// najviše 1 upit u sekundi i ne dozvoljava pretragu pri svakom slovu, OSRM
/// demo server bez garancije. Pre objave sa mnogo korisnika treba sopstveni
/// ili plaćeni server (videti KNOWN_ISSUES.md).
class NavigationService {
  NavigationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _userAgent = 'TaksimetarBalkan/1.0 (rs.taksimetar.balkan)';
  static const _timeout = Duration(seconds: 10);

  /// Okvir pretrage kad lokacija vozača nije poznata (Srbija i okolina).
  static const balkanBox = '13.0,40.0,30.0,48.5';

  /// Pretraga adrese za predloge dok se kuca: Photon, pa Nominatim ako
  /// Photon ne odgovori. Rezultati latinicom, najbliži vozaču prvi.
  Future<List<Place>> search(String query, {double? nearLat, double? nearLon}) async {
    final q = PlaceSearch.normalizeQuery(query);
    if (q.length < 3) return const [];
    List<Place> found;
    try {
      found = await _searchPhoton(q, nearLat: nearLat, nearLon: nearLon);
    } catch (_) {
      found = await _searchNominatim(q, nearLat: nearLat, nearLon: nearLon);
    }
    return PlaceSearch.rank(found, nearLat: nearLat, nearLon: nearLon);
  }

  Future<List<Place>> _searchPhoton(
    String q, {
    double? nearLat,
    double? nearLon,
  }) async {
    final near = nearLat != null && nearLon != null;
    final params = {
      'q': q,
      // više kandidata, pa redosled po blizini radimo sami (PlaceSearch.rank)
      'limit': '20',
      if (near) ...{
        // prednost bližim rezultatima; okvir ~±250 km isključuje druge kontinente
        'lat': '$nearLat',
        'lon': '$nearLon',
        'bbox': '${nearLon - 3},${nearLat - 2.5},${nearLon + 3},${nearLat + 2.5}',
      } else
        'bbox': balkanBox,
    };
    final uri = Uri.https('photon.komoot.io', '/api/', params);
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(_timeout);
    if (res.statusCode != 200) {
      throw NavigationException('Pretraga nije uspela (${res.statusCode}).');
    }
    return parsePhoton(utf8.decode(res.bodyBytes));
  }

  Future<List<Place>> _searchNominatim(
    String q, {
    double? nearLat,
    double? nearLon,
  }) async {
    final params = {
      'q': q,
      'format': 'jsonv2',
      'limit': '6',
      // latinica kao u ostatku aplikacije, pa ćirilica/engleski gde nema latinice
      'accept-language': 'sr-Latn,sr,en',
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

  /// Vrste OSM objekata koje vozaču ne trebaju (reke, vrhovi, granice opština).
  static const _skipKeys = {'waterway', 'natural', 'boundary', 'power'};

  /// GeoJSON odgovor Photon-a u mesta sa natpisom latinicom:
  /// „Karađorđeva, Smederevo”, „Cara Lazara 7, Seone”, „Vučak, Podunavski…”.
  static List<Place> parsePhoton(String body) {
    final data = jsonDecode(body);
    if (data is! Map || data['features'] is! List) return const [];
    final places = <Place>[];
    for (final f in data['features'] as List) {
      if (f is! Map || f['properties'] is! Map || f['geometry'] is! Map) continue;
      final p = f['properties'] as Map;
      final coords = (f['geometry'] as Map)['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lon = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lon == null || _skipKeys.contains(p['osm_key'])) continue;
      String? str(String k) {
        final v = p[k];
        return v is String && v.trim().isNotEmpty ? v.trim() : null;
      }

      final name = str('name');
      final street = str('street');
      final number = str('housenumber');
      final address = street == null ? null : [street, ?number].join(' ');
      final title = name != null && address != null && name != street
          ? '$name, $address'
          : (name ?? address);
      if (title == null) continue;
      final where = str('city') ??
          str('town') ??
          str('village') ??
          str('district') ??
          str('county') ??
          str('state');
      final label = where == null || where == title ? title : '$title, $where';
      places.add(Place(label: PlaceSearch.toLatin(label), lat: lat, lon: lon));
    }
    return places;
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
