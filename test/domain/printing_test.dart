import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/ride_record.dart';
import 'package:taksimetar_balkan/domain/printing/escpos.dart';
import 'package:taksimetar_balkan/domain/printing/receipt.dart';

RideRecord ride({int adj = 0, String status = 'completed'}) => RideRecord(
      id: 7,
      startTime: DateTime.utc(2026, 10, 19, 10, 0),
      endTime: DateTime.utc(2026, 10, 19, 10, 25, 30),
      distanceMeters: 12345,
      waitingSeconds: 185,
      startPrice: 250,
      kmPrice: 988,
      waitingPrice: 41,
      minPriceAdjustment: adj,
      totalPrice: 1279 + adj,
      status: status,
    );

void main() {
  group('EscPos.encode', () {
    test('ASCII prolazi nepromenjen', () {
      expect(EscPos.encode('Taxi 12', PrintMode.cp852), 'Taxi 12'.codeUnits);
    });

    test('CP852: naša slova', () {
      expect(EscPos.encode('čćžšđ', PrintMode.cp852), [0x9F, 0x86, 0xA7, 0xE7, 0xD0]);
      expect(EscPos.encode('ČĆŽŠĐ', PrintMode.cp852), [0xAC, 0x8F, 0xA6, 0xE6, 0xD1]);
    });

    test('CP1250: naša slova', () {
      expect(EscPos.encode('čćžšđ', PrintMode.cp1250), [0xE8, 0xE6, 0x9E, 0x9A, 0xF0]);
      expect(EscPos.encode('ČĆŽŠĐ', PrintMode.cp1250), [0xC8, 0xC6, 0x8E, 0x8A, 0xD0]);
    });

    test('bez kvačica: transliteracija', () {
      expect(EscPos.transliterate('Đorđe Čačak, šećer, Žabalj'), 'Djordje Cacak, secer, Zabalj');
      expect(EscPos.encode('đak', PrintMode.plain), 'djak'.codeUnits);
    });

    test('nepoznat znak postaje ?', () {
      expect(EscPos.encode('€', PrintMode.cp852), [0x3F]);
      expect(EscPos.encode('ж', PrintMode.plain), [0x3F]);
    });
  });

  group('EscPos.raster', () {
    test('GS v 0 zaglavlje i bitovi (MSB levo)', () {
      // 10×2: prvi red prvi piksel crn, drugi red deveti piksel crn
      final px = List<bool>.filled(20, false);
      px[0] = true;
      px[10 + 8] = true;
      final out = EscPos.raster(10, 2, px);
      expect(out.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 2, 0, 2, 0]);
      expect(out.sublist(8), [0x80, 0x00, 0x00, 0x80]);
    });

    test('visina se deli na trake', () {
      final out = EscPos.raster(8, 300, List<bool>.filled(2400, false), bandRows: 128);
      final headers = <int>[];
      for (var i = 0; i < out.length - 3; i++) {
        if (out[i] == 0x1D && out[i + 1] == 0x76 && out[i + 2] == 0x30) headers.add(i);
      }
      expect(headers.length, 3); // 128 + 128 + 44
      expect(out.length, 3 * 8 + 300); // 1 bajt po redu
    });

    test('pogrešan broj piksela → greška', () {
      expect(() => EscPos.raster(8, 2, [true]), throwsArgumentError);
    });
  });

  group('Receipt', () {
    test('twoColumns poravnava i skraćuje', () {
      expect(Receipt.twoColumns('Start', '250 din', 20), 'Start        250 din');
      expect(Receipt.twoColumns('Veoma dugačak naziv', '1 din', 12), 'Veoma  1 din');
      expect(Receipt.twoColumns('x', '123', 3), '123');
    });

    test('račun za vožnju: zaglavlje, stavke, ukupno, oznaka da nije fiskalni', () {
      final lines = Receipt.forRide(ride(), header: ['TAXI MARKO', '', 'tel 060 123'], eurRateMilli: 117200)
          .map((l) => l.text)
          .toList();
      expect(lines.first, 'TAXI MARKO');
      expect(lines[1], 'tel 060 123');
      expect(lines, contains(Receipt.twoColumns('Distanca', '12.35 km', 32)));
      expect(lines, contains(Receipt.twoColumns('Trajanje', '25:30', 32)));
      expect(lines, contains(Receipt.twoColumns('Kilometraža', '988 din', 32)));
      expect(lines, contains('1279 din'));
      expect(lines, contains('(10.91 EUR)'));
      expect(lines, contains(Receipt.notFiscal));
      expect(lines.any((l) => l.contains('minimalne')), false);
    });

    test('svaki red staje u širinu; veliki red u polovinu', () {
      for (final l in Receipt.forRide(ride(adj: 21, status: 'interrupted'))) {
        expect(l.text.length, lessThanOrEqualTo(l.large ? 16 : 32), reason: l.text);
      }
    });

    test('bez zaglavlja nema praznog separatora na vrhu', () {
      final first = Receipt.forRide(ride()).first.text;
      expect(first.startsWith('Početak'), true);
    });
  });
}
