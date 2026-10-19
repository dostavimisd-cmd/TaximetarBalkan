import '../models/tariff.dart';

/// Fiksna relacija (npr. grad → aerodrom) sa cenom koju unosi korisnik.
/// Vožnja se i dalje meri (km, vreme), ali se naplaćuje fiksna cena.
class FixedRoute {
  final int id; // 0 = nova
  final String name;
  final String fromLabel;
  final String toLabel;
  final int price; // ceo dinar

  const FixedRoute({
    this.id = 0,
    required this.name,
    this.fromLabel = '',
    this.toLabel = '',
    required this.price,
  });

  String? validate() {
    if (name.trim().isEmpty) return 'Naziv relacije je obavezan.';
    if (price <= 0) return 'Cena relacije mora biti veća od 0.';
    if (price > Tariff.maxPrice) return 'Cena ne sme biti veća od ${Tariff.maxPrice} din.';
    return null;
  }

  String describe({bool english = false}) {
    final unit = english ? 'RSD' : 'din';
    final route = [fromLabel.trim(), toLabel.trim()].where((s) => s.isNotEmpty).join(' → ');
    return route.isEmpty ? '$price $unit' : '$route · $price $unit';
  }
}
