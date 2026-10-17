class Tariff {
  final int startPrice;
  final int pricePerKm;
  final int waitingPricePerMin;
  final int minPrice;

  const Tariff({
    required this.startPrice,
    required this.pricePerKm,
    required this.waitingPricePerMin,
    required this.minPrice,
  });
}