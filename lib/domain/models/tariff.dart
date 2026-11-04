import 'tariff_schedule.dart';

class Tariff {
  /// Tehnička gornja granica cene (sprečava prekoračenje int-a pri obračunu
  /// metar * cena); nije tarifa ni zakonski limit.
  static const int maxPrice = 1000000;

  final int id;
  final String name;
  final int startPrice;
  final int pricePerKm;
  /// Cena čekanja po minutu u para (1/100 dinara): 13.4 din/min = 1340.
  final int waitingParaPerMin;
  final int minPrice;

  /// Cena po km za prvi kilometar (prvih 1000 m posle kalibracije).
  /// null = prvi km kao i ostali; 0 = prvi km je uračunat u start.
  final int? firstKmPrice;

  /// Raspored za automatski izbor; null = samo ručni izbor.
  final TariffSchedule? schedule;

  const Tariff({
    this.id = 1,
    this.name = 'Standard',
    required this.startPrice,
    required this.pricePerKm,
    required this.waitingParaPerMin,
    required this.minPrice,
    this.firstKmPrice,
    this.schedule,
  });

  /// N19: vraća opis greške ili null ako je tarifa ispravna.
  String? validate() {
    final prices = [startPrice, pricePerKm, waitingParaPerMin, minPrice, ?firstKmPrice];
    if (prices.any((p) => p < 0)) return 'Cene ne smeju biti negativne.';
    if ([startPrice, pricePerKm, minPrice, ?firstKmPrice].any((p) => p > maxPrice) ||
        waitingParaPerMin > maxPrice * 100) {
      return 'Cena ne sme biti veća od $maxPrice din.';
    }
    if (name.trim().isEmpty) return 'Naziv tarife je obavezan.';
    return schedule?.validate();
  }

  Tariff copyWith({
    int? id,
    String? name,
    int? startPrice,
    int? pricePerKm,
    int? waitingParaPerMin,
    int? minPrice,
    int? firstKmPrice,
    bool clearFirstKm = false,
    TariffSchedule? schedule,
    bool clearSchedule = false,
  }) {
    return Tariff(
      id: id ?? this.id,
      name: name ?? this.name,
      startPrice: startPrice ?? this.startPrice,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      waitingParaPerMin: waitingParaPerMin ?? this.waitingParaPerMin,
      minPrice: minPrice ?? this.minPrice,
      firstKmPrice: clearFirstKm ? null : (firstKmPrice ?? this.firstKmPrice),
      schedule: clearSchedule ? null : (schedule ?? this.schedule),
    );
  }
}
