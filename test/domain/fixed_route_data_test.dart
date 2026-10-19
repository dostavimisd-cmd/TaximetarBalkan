import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/fixed_route_import.dart';

/// Proverava spisak iz docs/fiksne_relacije.txt (prepisan iz cenovnika
/// koji važi od 06.05.2026.): svaki red mora da se uveze, bez duplikata.
void main() {
  test('cenovnik se uvozi bez preskočenih redova i duplikata', () {
    final text = File('docs/fiksne_relacije.txt').readAsStringSync();
    final r = FixedRouteImport.parse(text);
    expect(r.issues, isEmpty, reason: r.issues.map((i) => 'red ${i.line}: ${i.reason}').join('\n'));
    expect(r.routes.length, 91);

    final names = r.routes.map((x) => x.name.toLowerCase()).toList();
    expect(names.toSet().length, names.length, reason: 'duplirani nazivi');
  });

  test('pretraga nalazi relacije bez kvačica', () {
    final r = FixedRouteImport.parse(File('docs/fiksne_relacije.txt').readAsStringSync());
    expect(FixedRouteImport.search(r.routes, 'aerodrom').single.price, 5500);
    expect(FixedRouteImport.search(r.routes, 'pozarevac').length, greaterThanOrEqualTo(2));
    expect(FixedRouteImport.search(r.routes, 'kostolac').single.price, 2800);
  });
}
