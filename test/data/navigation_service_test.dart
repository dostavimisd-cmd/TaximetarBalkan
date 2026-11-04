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

  // Photon: ćirilica iz OSM-a, reka (izbacuje se), dalji grad pre bližeg u odgovoru
  const photon = '''{"features": [
    {"geometry": {"coordinates": [20.4612, 44.8125]},
     "properties": {"name": "Карађорђева", "city": "Београд", "osm_key": "highway"}},
    {"geometry": {"coordinates": [20.93, 44.62]},
     "properties": {"name": "Дунав", "osm_key": "waterway"}},
    {"geometry": {"coordinates": [20.927, 44.664]},
     "properties": {"name": "Карађорђева", "city": "Смедерево", "osm_key": "highway"}},
    {"geometry": {"coordinates": [20.819, 44.635]},
     "properties": {"street": "Цара Лазара", "housenumber": "7", "village": "Сеоне", "osm_key": "place"}},
    {"properties": {"name": "bez koordinata"}}
  ]}''';

  test('parsePhoton: latinica, ulica i broj, bez reka i neispravnih', () {
    final places = NavigationService.parsePhoton(photon);
    expect(places.map((p) => p.label), [
      'Karađorđeva, Beograd',
      'Karađorđeva, Smederevo',
      'Cara Lazara 7, Seone',
    ]);
    expect(NavigationService.parsePhoton('[]'), isEmpty);
  });

  test('search: kratak upit ne ide na mrežu; Photon sa lokacijom, najbliže prvo', () async {
    late http.Request seen;
    final service = NavigationService(
      client: MockClient((req) async {
        seen = req;
        // bez charset-a u zaglavlju, kao kad server ne navede kodiranje
        return http.Response.bytes(utf8.encode(photon), 200);
      }),
    );
    expect(await service.search('ab'), isEmpty);

    // vozač u Smederevu
    final places = await service.search(' Karađorđeva ', nearLat: 44.66, nearLon: 20.93);
    expect(seen.url.host, 'photon.komoot.io');
    expect(seen.url.queryParameters['q'], 'Karadjordjeva'); // đ → dj
    expect(seen.url.queryParameters['lat'], '44.66');
    expect(seen.url.queryParameters['bbox'], isNotNull);
    expect(seen.headers['User-Agent'], contains('rs.taksimetar.balkan'));
    expect(places.map((p) => p.label), [
      'Karađorđeva, Smederevo',
      'Cara Lazara 7, Seone',
      'Karađorđeva, Beograd',
    ]);
    expect(places.first.distanceMeters, lessThan(1000));
  });

  test('search: Photon ne radi → Nominatim (UTF-8 bez charset-a)', () async {
    final hosts = <String>[];
    final service = NavigationService(
      client: MockClient((req) async {
        hosts.add(req.url.host);
        if (req.url.host == 'photon.komoot.io') return http.Response('', 503);
        expect(req.url.queryParameters['viewbox'], isNotNull);
        return http.Response.bytes(utf8.encode(nominatim), 200);
      }),
    );
    final places = await service.search('Knez Mihailova', nearLat: 44.8, nearLon: 20.4);
    expect(hosts, ['photon.komoot.io', 'nominatim.openstreetmap.org']);
    expect(places.first.label, 'Knez Mihailova, Beograd'); // bliži
    expect(places.last.label, 'Đure Jakšića, Novi Sad');
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
