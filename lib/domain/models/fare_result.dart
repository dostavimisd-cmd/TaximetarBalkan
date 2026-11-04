class FareResult {
  final int startPrice;
  final int kmPrice;
  final int waitingPrice;
  final int minPriceAdjustment; // Koliko je dodato da se dosegne min cena
  /// Zbir doplata (posle minimalne cene); 0 = bez doplata.
  final int extrasPrice;
  final int totalPrice;
  final bool isMinPriceApplied;

  const FareResult({
    required this.startPrice,
    required this.kmPrice,
    required this.waitingPrice,
    required this.minPriceAdjustment,
    this.extrasPrice = 0,
    required this.totalPrice,
    required this.isMinPriceApplied,
  });
}