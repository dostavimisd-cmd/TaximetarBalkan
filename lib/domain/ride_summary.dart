import 'models/ride_record.dart';

/// Tekst i pomoćne vrednosti za rezime vožnje (prikaz, deljenje).
class RideSummary {
  static String _two(int v) => v.toString().padLeft(2, '0');

  static String clock(int totalSeconds) {
    final h = totalSeconds ~/ 3600, m = (totalSeconds % 3600) ~/ 60, s = totalSeconds % 60;
    return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
  }

  static String dateTime(DateTime utc) {
    final t = utc.toLocal();
    return '${_two(t.day)}.${_two(t.month)}.${t.year}. ${_two(t.hour)}:${_two(t.minute)}';
  }

  /// "34.2 km/h" ili "—" kad je vožnja prekratka za smislen prosek.
  static String speed(RideRecord r) {
    final v = r.averageSpeedKmh;
    return v == null ? '—' : '${v.toStringAsFixed(1)} km/h';
  }

  /// Tekst za deljenje (poruka, mejl). Ne sadrži podatke o lokaciji.
  static String shareText(RideRecord r, {String? header}) {
    final lines = <String>[
      if (header != null && header.trim().isNotEmpty) header.trim(),
      'VOŽNJA ${dateTime(r.startTime)}',
      if (r.fixedRouteName != null) 'Relacija: ${r.fixedRouteName}',
      'Distanca: ${(r.distanceMeters / 1000).toStringAsFixed(2)} km',
      if (r.duration != null) 'Trajanje: ${clock(r.duration!.inSeconds)}',
      if (r.pausedSeconds > 0) 'Pauza: ${clock(r.pausedSeconds)}',
      'Čekanje: ${clock(r.waitingSeconds)}',
      if (r.fixedRouteName == null) ...[
        'Start: ${r.startPrice} din',
        'Kilometraža: ${r.kmPrice} din',
        'Čekanje: ${r.waitingPrice} din',
        if (r.minPriceAdjustment > 0) 'Do minimalne: ${r.minPriceAdjustment} din',
      ],
      'UKUPNO: ${r.totalPrice} din',
      if (r.isInterrupted) '(vožnja prekinuta, iznos do prekida)',
      '',
      'Ovo nije fiskalni račun.',
    ];
    return lines.join('\n');
  }
}
