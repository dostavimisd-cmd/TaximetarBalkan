import 'tariff.dart';

/// Trošak u smeni (gorivo, pranje, parking…), ceo dinar. Unosi ga vozač,
/// najčešće pri završetku smene; ne ulazi u cenu vožnje (Pravilo 3).
class ShiftExpense {
  static const int maxNameLength = 40;

  /// Predlozi naziva u dijalogu (bez iznosa); vozač može da upiše svoj.
  static const List<String> suggestedNames = ['Gorivo', 'Pranje', 'Parking', 'Ostalo'];

  final int? id;
  final int shiftId;
  final String name;
  final int amount;

  const ShiftExpense({
    this.id,
    required this.shiftId,
    required this.name,
    required this.amount,
  });

  /// Opis greške ili null ako je trošak ispravan.
  String? validate() {
    if (name.trim().isEmpty) return 'Naziv troška je obavezan.';
    if (name.trim().length > maxNameLength) {
      return 'Naziv troška je predugačak (najviše $maxNameLength znakova).';
    }
    if (amount <= 0 || amount > Tariff.maxPrice) {
      return 'Iznos troška mora biti od 1 do ${Tariff.maxPrice} din.';
    }
    return null;
  }
}
