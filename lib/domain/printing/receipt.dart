import '../currency_converter.dart';
import '../models/ride_record.dart';

enum ReceiptAlign { left, center, right }

/// Jedan red računa. [large] = dvostruka veličina (pola znakova u redu).
class ReceiptLine {
  final String text;
  final ReceiptAlign align;
  final bool bold;
  final bool large;

  const ReceiptLine(this.text, {this.align = ReceiptAlign.left, this.bold = false, this.large = false});

  @override
  String toString() => text;
}

/// Sadržaj računa za vožnju, nezavisno od štampača (tekst ili slika).
/// Na računu uvek piše da nije fiskalni (SPEC: jasna oznaka na računu).
class Receipt {
  static const String notFiscal = 'Ovo nije fiskalni račun.';

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _date(DateTime utc) {
    final t = utc.toLocal();
    return '${_two(t.day)}.${_two(t.month)}.${t.year} ${_two(t.hour)}:${_two(t.minute)}';
  }

  static String _clock(int seconds) {
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
    return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
  }

  /// Levo i desno u istom redu; levo se skraćuje ako ne staje.
  static String twoColumns(String left, String right, int width) {
    final space = width - right.length - 1;
    if (space <= 0) return right.length > width ? right.substring(0, width) : right;
    final l = left.length > space ? left.substring(0, space) : left;
    return '${l.padRight(space)} $right';
  }

  static List<ReceiptLine> forRide(
    RideRecord ride, {
    List<String> header = const [],
    int width = 32,
    int? eurRateMilli,
  }) {
    final sep = ReceiptLine('-' * width);
    ReceiptLine row(String l, String r, {bool bold = false}) =>
        ReceiptLine(twoColumns(l, r, width), bold: bold);
    final duration = ride.duration;

    return [
      for (final h in header)
        if (h.trim().isNotEmpty) ReceiptLine(h.trim(), align: ReceiptAlign.center, bold: true),
      if (header.any((h) => h.trim().isNotEmpty)) sep,
      row('Početak', _date(ride.startTime)),
      if (ride.endTime != null) row('Kraj', _date(ride.endTime!)),
      row('Distanca', '${(ride.distanceMeters / 1000).toStringAsFixed(2)} km'),
      if (duration != null && !duration.isNegative) row('Trajanje', _clock(duration.inSeconds)),
      row('Čekanje', _clock(ride.waitingSeconds)),
      sep,
      row('Start', '${ride.startPrice} din'),
      row('Kilometraža', '${ride.kmPrice} din'),
      row('Čekanje', '${ride.waitingPrice} din'),
      if (ride.minPriceAdjustment > 0) row('Do minimalne', '${ride.minPriceAdjustment} din'),
      sep,
      const ReceiptLine('UKUPNO', align: ReceiptAlign.center, bold: true),
      ReceiptLine('${ride.totalPrice} din', align: ReceiptAlign.center, bold: true, large: true),
      if (eurRateMilli != null)
        ReceiptLine('(${CurrencyConverter.formatForeign(ride.totalPrice, eurRateMilli)} EUR)',
            align: ReceiptAlign.center),
      if (ride.isInterrupted)
        const ReceiptLine('Prekinuta - iznos do prekida', align: ReceiptAlign.center),
      sep,
      const ReceiptLine(notFiscal, align: ReceiptAlign.center),
      const ReceiptLine('Pomoćni taksimetar', align: ReceiptAlign.center),
    ];
  }

  /// Probna stranica: naša slova u svakom režimu, da korisnik izabere red
  /// koji je odštampan ispravno.
  static const String sample = 'č ć ž š đ Č Ć Ž Š Đ';
}
