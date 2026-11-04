import 'models/ride_record.dart';

/// Tabela vožnji za izvoz izveštaja (CSV za Excel i PDF). Nazivi kolona i
/// oznake dolaze spolja (prevod je u UI sloju); novac su celi dinari.
class ReportExport {
  static String _two(int v) => v.toString().padLeft(2, '0');

  static String date(DateTime utc) {
    final l = utc.toLocal();
    return '${_two(l.day)}.${_two(l.month)}.${l.year}.';
  }

  static String time(DateTime utc) {
    final l = utc.toLocal();
    return '${_two(l.hour)}:${_two(l.minute)}';
  }

  /// h:mm:ss (bez pauze); prazno za vožnju bez kraja.
  static String duration(Duration? d) {
    if (d == null) return '';
    final s = d.inSeconds;
    return '${s ~/ 3600}:${_two((s % 3600) ~/ 60)}:${_two(s % 60)}';
  }

  static String clock(int seconds) => '${_two(seconds ~/ 60)}:${_two(seconds % 60)}';

  /// Kilometri sa dve decimale i decimalnim zarezom (srpski Excel).
  static String km(int meters) {
    final hundredths = (meters + 5) ~/ 10; // zaokruživanje na 10 m
    return '${hundredths ~/ 100},${_two(hundredths % 100)}';
  }

  /// Vožnje od najstarije ka najnovijoj.
  static List<RideRecord> ordered(Iterable<RideRecord> rides) =>
      rides.toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// Napomena uz vožnju: naziv fiksne relacije ili oznaka prekinute vožnje.
  static String note(RideRecord r, {required String interruptedLabel}) {
    final parts = [
      if (r.fixedRouteName != null) r.fixedRouteName!,
      if (r.isInterrupted) interruptedLabel,
    ];
    return parts.join(', ');
  }

  /// Kolone CSV-a (13), istim redom kao [csvHeaders] koji daje UI.
  static List<String> csvRow(RideRecord r, {required String interruptedLabel}) => [
        date(r.startTime),
        time(r.startTime),
        r.endTime == null ? '' : time(r.endTime!),
        duration(r.activeDuration),
        km(r.distanceMeters),
        clock(r.waitingSeconds),
        '${r.startPrice}',
        '${r.kmPrice}',
        '${r.waitingPrice}',
        '${r.minPriceAdjustment}',
        '${r.totalPrice}',
        note(r, interruptedLabel: interruptedLabel),
        '${r.id}',
      ];

  static const int csvColumns = 13;

  static String _cell(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// CSV za Excel sa srpskim podešavanjima: `;` između kolona, decimalni
  /// zarez, UTF-8 sa BOM (da Excel ispravno prikaže č ć ž š đ), red za zbir.
  static String csv(
    Iterable<RideRecord> rides, {
    required List<String> headers,
    required String totalLabel,
    required String interruptedLabel,
  }) {
    if (headers.length != csvColumns) {
      throw ArgumentError('CSV ima $csvColumns kolona, a naziva je ${headers.length}.');
    }
    final list = ordered(rides);
    final lines = <List<String>>[
      headers,
      for (final r in list) csvRow(r, interruptedLabel: interruptedLabel),
      [
        totalLabel,
        '', '', '',
        km(list.fold(0, (s, r) => s + r.distanceMeters)),
        clock(list.fold(0, (s, r) => s + r.waitingSeconds)),
        '', '', '', '',
        '${list.fold(0, (s, r) => s + r.totalPrice)}',
        '', '',
      ],
    ];
    return '﻿${lines.map((l) => l.map(_cell).join(';')).join('\r\n')}\r\n';
  }
}
