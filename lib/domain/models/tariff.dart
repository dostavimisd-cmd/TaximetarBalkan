class Tariff {
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
}