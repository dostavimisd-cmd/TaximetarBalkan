import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:taksimetar_balkan/domain/models/ride_record.dart';
import 'package:taksimetar_balkan/domain/report_export.dart';
import 'package:taksimetar_balkan/presentation/printing/report_pdf.dart';

RideRecord ride(int id, DateTime startUtc, {
  int meters = 2520,
  int total = 459,
  String status = 'completed',
  String? fixed,
}) =>
    RideRecord(
      id: id,
      startTime: startUtc,
      endTime: startUtc.add(const Duration(minutes: 7, seconds: 30)),
      distanceMeters: meters,
      waitingSeconds: 75,
      startPrice: 250,
      kmPrice: 202,
      waitingPrice: 7,
      minPriceAdjustment: 0,
      totalPrice: total,
      status: status,
      fixedRouteName: fixed,
    );

const headers = [
  'Datum', 'Početak', 'Kraj', 'Trajanje', 'Km', 'Čekanje', 'Start',
  'Kilometraža', 'Čekanje (din)', 'Dopuna do minimalne', 'Doplata', 'Ukupno (din)', 'Napomena', 'Broj',
];

void main() {
  test('km sa decimalnim zarezom, zaokruženo na 10 m', () {
    expect(ReportExport.km(2520), '2,52');
    expect(ReportExport.km(2525), '2,53');
    expect(ReportExport.km(999), '1,00');
    expect(ReportExport.km(0), '0,00');
    expect(ReportExport.km(12004), '12,00');
  });

  test('trajanje h:mm:ss i čekanje mm:ss', () {
    expect(ReportExport.duration(const Duration(minutes: 7, seconds: 30)), '0:07:30');
    expect(ReportExport.duration(const Duration(hours: 1, seconds: 5)), '1:00:05');
    expect(ReportExport.duration(null), '');
    expect(ReportExport.clock(75), '01:15');
  });

  test('CSV: BOM, ; između kolona, vožnje po vremenu, zbir na kraju', () {
    final a = ride(1, DateTime.utc(2026, 11, 4, 8, 0));
    final b = ride(2, DateTime.utc(2026, 11, 4, 6, 0), meters: 1000, total: 300);
    final csv = ReportExport.csv([a, b],
        headers: headers, totalLabel: 'Ukupno', interruptedLabel: 'prekinuta');

    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.substring(1).trimRight().split('\r\n');
    expect(lines, hasLength(4)); // zaglavlje, 2 vožnje, zbir
    expect(lines.first.split(';'), headers);
    expect(lines[1].split(';').last, '2'); // starija vožnja prva
    expect(lines[2].split(';').last, '1');
    final total = lines.last.split(';');
    expect(total.first, 'Ukupno');
    expect(total[4], '3,52');
    expect(total[11], '759');
    for (final l in lines) {
      expect(l.split(';'), hasLength(ReportExport.csvColumns));
    }
  });

  test('CSV: napomena sa ; i navodnicima se ispravno citira', () {
    final r = ride(3, DateTime.utc(2026, 11, 4), fixed: 'Aerodrom; "Tesla"', status: 'interrupted');
    final csv = ReportExport.csv([r],
        headers: headers, totalLabel: 'Ukupno', interruptedLabel: 'prekinuta');
    expect(csv, contains('"Aerodrom; ""Tesla"", prekinuta"'));
  });

  test('CSV: broj naziva kolona mora da odgovara', () {
    expect(
      () => ReportExport.csv([], headers: const ['a'], totalLabel: 'U', interruptedLabel: 'p'),
      throwsArgumentError,
    );
  });

  test('PDF sa našim slovima se pravi (više strana)', () async {
    pw.Font font(String w) => pw.Font.ttf(
        ByteData.sublistView(File('assets/fonts/NotoSans-$w.ttf').readAsBytesSync()));
    final rows = [
      for (var i = 0; i < 80; i++)
        ['04.11.2026.', '08:00', '0:07:30', '2,52', '01:15', '459', 'Čačak – Đerdap, Šabac, Žabalj'],
    ];
    final bytes = await buildReportPdf(
      title: 'Izveštaj',
      period: '04.11.2026.',
      headerLines: const ['Taksi Đorđević', 'Smederevo'],
      summary: const [('Ukupno', '36720 din'), null, ('Vožnji', '80')],
      columns: const ['Datum', 'Početak', 'Trajanje', 'Km', 'Čekanje', 'Ukupno (din)', 'Napomena'],
      rows: rows,
      footer: 'nije fiskalni dokument',
      regular: font('Regular'),
      bold: font('Bold'),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });
}
