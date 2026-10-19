import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taksimetar_balkan/data/services/navigation_service.dart';

void main() {
  const nominatim = '''[
    {"lat": "44.8125", "lon": "20.4612", "display_name": "Knez Mihailova, Beograd"},
    {"lat": "x", "lon": "20.0", "display_name": "loš red"},
    {"lat": "45.2671", "lon": "19.8335", "display_name": "Đure Jakšića, Novi Sad"}
  ]''';

  const osrm = '''{
    "code": "Ok",
    "routes": [{
      "distance": 1234.6,
      "duration": 301.2,
      "geometry": {"type": "LineString", "coordinates": [[20.46, 44.81], [20.47, 44.82]]}
    }]
  }''';

  test('parsePlaces preskače neispravne redove', () {
    final places = NavigationService.parsePlaces(nominatim);
    expect(nominatim.contains('loš'), true);
    expect(places.map((p) => p.label), ['Knez Mihailova, Beograd', 'Đure Jakšića, Novi Sad']);
    expect(places.first.lat, 44.8125);
    expect(places.first.lon, 20.4612);
    expect(NavigationService.parsePlaces('{}'), isEmpty);
  });

  test('parseRoute: GeoJSON [lon, lat] → (lat, lon), zaokruženo', () {
    final r = NavigationService.parseRoute(osrm);
    expect(r.points, [(44.81, 20.46), (44.82, 20.47)]);
    expect(r.distanceMeters, 1235);
    expect(r.durationSeconds, 301);
    expect(r.describe(), '1.2 km · ~5 min');
  });

  test('parseRoute: bez rute → greška', () {
    expect(() => NavigationService.parseRoute('{"code":"NoRoute","routes":[]}'),
        throwsA(isA<NavigationException>()));
  });

  test('search: kratak upit ne ide na mrežu; šalje User-Agent i viewbox', () async {
    late http.Request seen;
    final service = NavigationService(
      client: MockClient((req) async {
        seen = req;
        // bez charset-a u zaglavlju, kao kad server ne navede kodiranje
        return http.Response.bytes(utf8.encode(nominatim), 200);
      }),
    );
    expect(await service.search('ab'), isEmpty);

    final places = await service.search('Knez Mihailova', nearLat: 44.8, nearLon: 20.4);
    expect(places.length, 2);
    expect(places.last.label, 'Đure Jakšića, Novi Sad'); // UTF-8 bez charset-a
    expect(seen.headers['User-Agent'], contains('rs.taksimetar.balkan'));
    expect(seen.url.host, 'nominatim.openstreetmap.org');
    expect(seen.url.queryParameters['q'], 'Knez Mihailova');
    expect(seen.url.queryParameters['viewbox'], isNotNull);
  });

  test('route: greška servera → NavigationException', () async {
    final service = NavigationService(
      client: MockClient((_) async => http.Response('err', 503)),
    );
    expect(() => service.route(44.8, 20.4, 44.9, 20.5), throwsA(isA<NavigationException>()));
  });

  test('route: URL je lon,lat;lon,lat', () async {
    late Uri url;
    final service = NavigationService(
      client: MockClient((req) async {
        url = req.url;
        return http.Response(osrm, 200);
      }),
    );
    await service.route(44.8, 20.4, 44.9, 20.5);
    expect(url.path, '/route/v1/driving/20.4,44.8;20.5,44.9');
  });
}
