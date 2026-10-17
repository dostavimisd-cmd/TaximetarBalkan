class FareResult {
  final int startPrice;
  final int kmPrice;
  final int waitingPrice;
  final int minPriceAdjustment; // Koliko je dodato da se dosegne min cena
  final int totalPrice;
  final bool isMinPriceApplied;

  const FareResult({
    required this.startPrice,
    required this.kmPrice,
    required this.waitingPrice,
    required this.minPriceAdjustment,
    required this.totalPrice,
    required this.isMinPriceApplied,
  });
}