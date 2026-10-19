class Tariff {
  /// Tehnička gornja granica cene (sprečava prekoračenje int-a pri obračunu
  /// metar * cena); nije tarifa ni zakonski limit.
  static const int maxPrice = 1000000;

  final int id;
  final String name;
  final int startPrice;
  final int pricePerKm;
  final int waitingPricePerMin;
  final int minPrice;

  const Tariff({
    this.id = 1,
    this.name = 'Standard',
    required this.startPrice,
    required this.pricePerKm,
    required this.waitingPricePerMin,
    required this.minPrice,
  });

  /// N19: vraća opis greške ili null ako je tarifa ispravna.
  String? validate() {
    final prices = [startPrice, pricePerKm, waitingPricePerMin, minPrice];
    if (prices.any((p) => p < 0)) return 'Cene ne smeju biti negativne.';
    if (prices.any((p) => p > maxPrice)) {
      return 'Cena ne sme biti veća od $maxPrice.';
    }
    if (name.trim().isEmpty) return 'Naziv tarife je obavezan.';
    return null;
  }

  Tariff copyWith({
    int? id,
    String? name,
    int? startPrice,
    int? pricePerKm,
    int? waitingPricePerMin,
    int? minPrice,
  }) {
    return Tariff(
      id: id ?? this.id,
      name: name ?? this.name,
      startPrice: startPrice ?? this.startPrice,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      waitingPricePerMin: waitingPricePerMin ?? this.waitingPricePerMin,
      minPrice: minPrice ?? this.minPrice,
    );
  }
}
