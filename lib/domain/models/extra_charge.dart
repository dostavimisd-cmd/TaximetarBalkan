import 'dart:convert';

import 'tariff.dart';

/// Doplata (SR) / Extra (EN): stavka sa nazivom i iznosom u celim dinarima.
/// Spisak doplata unosi korisnik u Podešavanjima (Pravilo 3); tokom vožnje
/// se dodaju dugmetom „+”. [id] je red u `ride_extras` (null u spisku).
class ExtraCharge {
  static const int maxNameLength = 40;
  static const int maxCount = 20;

  final int? id;
  final String name;
  final int amount;

  const ExtraCharge({this.id, required this.name, required this.amount});

  /// Opis greške ili null ako je stavka ispravna.
  String? validate() {
    if (name.trim().isEmpty) return 'Naziv doplate je obavezan.';
    if (name.trim().length > maxNameLength) {
      return 'Naziv doplate je predugačak (najviše $maxNameLength znakova).';
    }
    if (amount <= 0 || amount > Tariff.maxPrice) {
      return 'Iznos doplate mora biti od 1 do ${Tariff.maxPrice} din.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {'id': ?id, 'name': name, 'amount': amount};

  /// Čita jednu stavku; neispravna daje null.
  static ExtraCharge? fromJson(Object? o) {
    if (o is! Map) return null;
    final name = o['name'], amount = o['amount'], id = o['id'];
    if (name is! String || amount is! num) return null;
    final e = ExtraCharge(
      id: id is num ? id.toInt() : null,
      name: name.trim(),
      amount: amount.toInt(),
    );
    return e.validate() == null ? e : null;
  }

  /// Spisak iz JSON teksta; neispravne stavke se preskaču, nikad ne baca.
  static List<ExtraCharge> decodeList(Object? source) {
    Object? data = source;
    if (source is String) {
      if (source.trim().isEmpty) return const [];
      try {
        data = jsonDecode(source);
      } catch (_) {
        return const [];
      }
    }
    if (data is! List) return const [];
    return [
      for (final o in data) ?fromJson(o),
    ].take(maxCount).toList();
  }

  static String encodeList(List<ExtraCharge> list) =>
      jsonEncode([for (final e in list) e.toJson()]);

  static int total(Iterable<ExtraCharge> list) =>
      list.fold(0, (s, e) => s + e.amount);

  @override
  bool operator ==(Object other) =>
      other is ExtraCharge &&
      other.id == id &&
      other.name == name &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(id, name, amount);
}
