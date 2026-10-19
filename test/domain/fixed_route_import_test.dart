import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/fixed_route_import.dart';
import 'package:taksimetar_balkan/domain/models/fixed_route.dart';

void main() {
  group('parsePrice', () {
    test('razni zapisi', () {
      expect(FixedRouteImport.parsePrice('2500'), 2500);
      expect(FixedRouteImport.parsePrice('2.500'), 2500);
      expect(FixedRouteImport.parsePrice('2 500'), 2500);
      expect(FixedRouteImport.parsePrice('2500 din'), 2500);
      expect(FixedRouteImport.parsePrice('2.500,00 RSD'), 2500); // nule iza zareza
      expect(FixedRouteImport.parsePrice('2500.00'), 2500);
      expect(FixedRouteImport.parsePrice('1200rsd'), 1200);
    });

    test('nevalidno', () {
      // "1,50" i "2.500,50" nisu celi dinari: bolje odbiti nego pogrešno naplatiti
      for (final bad in ['', 'abc', '0', '-5', '12345678', '1,50', '2.500,50', '99.9']) {
        expect(FixedRouteImport.parsePrice(bad), isNull, reason: bad);
      }
    });
  });

  group('parse', () {
    test('Naziv; Od; Do; Cena', () {
      final r = FixedRouteImport.parse('Aerodrom; Centar; Aerodrom Nikola Tesla; 2500');
      expect(r.issues, isEmpty);
      expect(r.routes.single.name, 'Aerodrom');
      expect(r.routes.single.fromLabel, 'Centar');
      expect(r.routes.single.toLabel, 'Aerodrom Nikola Tesla');
      expect(r.routes.single.price, 2500);
    });

    test('Naziv; Cena i Naziv - Cena', () {
      final r = FixedRouteImport.parse('Novi Sad; 4500\nSmederevo - 3.000 din');
      expect(r.issues, isEmpty);
      expect(r.routes.map((x) => x.name), ['Novi Sad', 'Smederevo']);
      expect(r.routes.map((x) => x.price), [4500, 3000]);
    });

    test('dva polja pre cene = od i do', () {
      final r = FixedRouteImport.parse('Beograd; Novi Sad; 5000');
      expect(r.routes.single.name, 'Beograd - Novi Sad');
      expect(r.routes.single.fromLabel, 'Beograd');
      expect(r.routes.single.toLabel, 'Novi Sad');
    });

    test('tabulator, prazni redovi, naslov i loše cene se prijavljuju', () {
      final r = FixedRouteImport.parse('RELACIJA\tCENA\n\nZemun\t1800\nSurčin - abc\nNaslov bez cene\n');
      expect(r.routes.map((x) => x.name), ['Zemun']);
      expect(r.issues.map((i) => i.line), [1, 4, 5]);
    });

    test('CRLF i razmaci', () {
      final r = FixedRouteImport.parse('  Pančevo ; 2200  \r\n  Vršac - 6000 ');
      expect(r.routes.map((x) => x.name), ['Pančevo', 'Vršac']);
    });
  });

  group('search', () {
    const routes = [
      FixedRoute(name: 'Aerodrom', fromLabel: 'Centar', toLabel: 'Surčin', price: 2500),
      FixedRoute(name: 'Đerdap', price: 9000),
      FixedRoute(name: 'Novi Sad', price: 4500),
    ];

    test('bez kvačica i velikih slova', () {
      expect(FixedRouteImport.search(routes, 'djerdap').map((r) => r.name), ['Đerdap']);
      expect(FixedRouteImport.search(routes, 'SURCIN').map((r) => r.name), ['Aerodrom']);
    });

    test('sve reči moraju da se poklope; prazan upit vraća sve', () {
      expect(FixedRouteImport.search(routes, 'novi sad').length, 1);
      expect(FixedRouteImport.search(routes, 'novi centar'), isEmpty);
      expect(FixedRouteImport.search(routes, '  ').length, 3);
    });
  });
}
