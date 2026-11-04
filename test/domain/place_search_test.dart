import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/navigation.dart';
import 'package:taksimetar_balkan/domain/place_search.dart';

void main() {
  test('ćirilica u latinicu, i dvoslovna slova', () {
    expect(PlaceSearch.toLatin('Карађорђева, Смедерево'), 'Karađorđeva, Smederevo');
    expect(PlaceSearch.toLatin('Љубе Ненадовића'), 'Ljube Nenadovića');
    expect(PlaceSearch.toLatin('ЊЕГОШЕВА'), 'NJEGOŠEVA');
    expect(PlaceSearch.toLatin('Џеп'), 'Džep');
    expect(PlaceSearch.toLatin('Kralja Petra 5'), 'Kralja Petra 5');
  });

  test('upit: đ kao dj, višak razmaka', () {
    expect(PlaceSearch.normalizeQuery('  Karađorđeva   5 '), 'Karadjordjeva 5');
    expect(PlaceSearch.normalizeQuery('Đure Jakšića'), 'Djure Jakšića');
  });

  test('redosled po blizini, dupli iste ulice blizu se spajaju', () {
    const places = [
      Place(label: 'Karađorđeva, Beograd', lat: 44.81, lon: 20.46),
      Place(label: 'Karađorđeva, Vranovo', lat: 44.596, lon: 20.986),
      Place(label: 'Karađorđeva, Vranovo', lat: 44.598, lon: 20.989),
      Place(label: 'Karađorđeva, Smederevo', lat: 44.664, lon: 20.927),
    ];
    final r = PlaceSearch.rank(places, nearLat: 44.66, nearLon: 20.93);
    expect(r.map((p) => p.label), [
      'Karađorđeva, Smederevo',
      'Karađorđeva, Vranovo',
      'Karađorđeva, Beograd',
    ]);
    expect(r.first.distanceMeters, lessThan(1000));
    // bez lokacije: redosled servera
    expect(PlaceSearch.rank(places).first.label, 'Karađorđeva, Beograd');
    expect(PlaceSearch.rank(places, nearLat: 44.66, nearLon: 20.93, limit: 1), hasLength(1));
  });

  test('udaljenost za prikaz', () {
    expect(PlaceSearch.formatDistance(847), '850 m');
    expect(PlaceSearch.formatDistance(12449), '12,4 km');
    expect(PlaceSearch.formatDistance(1000), '1,0 km');
  });
}
