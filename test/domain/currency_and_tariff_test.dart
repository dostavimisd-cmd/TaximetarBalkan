import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/currency_converter.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';

Tariff tariff({
  String name = 'T',
  int start = 100,
  int km = 50,
  int waiting = 10,
  int min = 200,
}) =>
    Tariff(
      name: name,
      startPrice: start,
      pricePerKm: km,
      waitingParaPerMin: waiting,
      minPrice: min,
    );

void main() {
  group('CurrencyConverter', () {
    test('parseRateMilli prihvata tačku i zarez, najviše 3 decimale', () {
      expect(CurrencyConverter.parseRateMilli('117.2'), 117200);
      expect(CurrencyConverter.parseRateMilli('117,20'), 117200);
      expect(CurrencyConverter.parseRateMilli(' 117 '), 117000);
      expect(CurrencyConverter.parseRateMilli('0.005'), 5);
    });

    test('parseRateMilli odbija nevalidan unos', () {
      for (final bad in ['', 'abc', '0', '0.000', '-5', '1.2345', '1..2', '117.2.1']) {
        expect(CurrencyConverter.parseRateMilli(bad), isNull, reason: bad);
      }
    });

    test('formatRate skida završne nule', () {
      expect(CurrencyConverter.formatRate(117200), '117.2');
      expect(CurrencyConverter.formatRate(117000), '117');
      expect(CurrencyConverter.formatRate(117250), '117.25');
    });

    test('formatForeign: celobrojno, zaokruženo na cent (.5 naviše)', () {
      // 1172 din / 117.2 = 10.00 EUR
      expect(CurrencyConverter.formatForeign(1172, 117200), '10.00');
      expect(CurrencyConverter.formatForeign(0, 117200), '0.00');
      // 300 / 117.2 = 2.5597... → 2.56
      expect(CurrencyConverter.formatForeign(300, 117200), '2.56');
      // tačno .5 centa: 1 din pri kursu 200 = 0.005 EUR → 0.01
      expect(CurrencyConverter.formatForeign(1, 200000), '0.01');
    });

    test('formatForeign baca na kurs <= 0', () {
      expect(() => CurrencyConverter.formatForeign(100, 0), throwsArgumentError);
    });
  });

  group('para (čekanje sa decimalama)', () {
    test('parsePara: tačka, zarez, najviše 2 decimale', () {
      expect(CurrencyConverter.parsePara('13.4'), 1340);
      expect(CurrencyConverter.parsePara('13,4'), 1340);
      expect(CurrencyConverter.parsePara('13,45'), 1345);
      expect(CurrencyConverter.parsePara('800'), 80000);
      expect(CurrencyConverter.parsePara('0'), 0);
      expect(CurrencyConverter.parsePara(' 0,5 '), 50);
    });

    test('parsePara odbija nevalidan unos', () {
      for (final bad in ['', 'a', '-1', '13.456', '1..2', '1,2,3', '.5']) {
        expect(CurrencyConverter.parsePara(bad), isNull, reason: bad);
      }
    });

    test('formatPara skida završne nule', () {
      expect(CurrencyConverter.formatPara(1340), '13.4');
      expect(CurrencyConverter.formatPara(1333), '13.33');
      expect(CurrencyConverter.formatPara(1500), '15');
      expect(CurrencyConverter.formatPara(5), '0.05');
    });
  });

  group('Tariff.validate (N19)', () {
    test('ispravna tarifa', () {
      expect(tariff().validate(), isNull);
      expect(tariff(start: 0, km: 0, waiting: 0, min: 0).validate(), isNull);
    });

    test('negativne cene se odbijaju', () {
      expect(tariff(start: -1).validate(), isNotNull);
      expect(tariff(km: -1).validate(), isNotNull);
      expect(tariff(waiting: -1).validate(), isNotNull);
      expect(tariff(min: -1).validate(), isNotNull);
    });

    test('preveliki iznosi (prekoračenje) se odbijaju', () {
      expect(tariff(km: Tariff.maxPrice + 1).validate(), isNotNull);
      expect(tariff(km: Tariff.maxPrice).validate(), isNull);
    });

    test('prazan naziv se odbija', () {
      expect(tariff(name: '   ').validate(), isNotNull);
    });
  });
}
