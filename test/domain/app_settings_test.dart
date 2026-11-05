import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/app_settings.dart';
import 'package:taksimetar_balkan/domain/models/navigation.dart';
import 'package:taksimetar_balkan/domain/printing/escpos.dart';

void main() {
  test('prazna baza → podrazumevane vrednosti (dosadašnje ponašanje)', () {
    final s = AppSettings.fromMap(const {});
    expect(s.eurRateMilli, isNull);
    expect(s.waitingSpeedKmh, 8);
    expect(s.calibrationPermille, 1000);
    expect(s.gpsAccuracyM, 15);
    expect(s.language, 'sr');
    expect(s.currency, 'RSD');
    expect(s.selectedTariffId, isNull);
    expect(s.autoTariff, false);
    expect(s.printMode, PrintMode.image); // naša slova uvek tačna
    expect(s.printerMac, isNull);
    expect(s.validate(), isNull);
  });

  test('toMap → fromMap vraća iste vrednosti', () {
    const s = AppSettings(
      eurRateMilli: 117200,
      waitingSpeedKmh: 6,
      calibrationPermille: 1025,
      gpsAccuracyM: 20,
      language: 'en',
      currency: 'EUR',
      selectedTariffId: 3,
      autoTariff: true,
      printerMac: '00:11:22:33:44:55',
      printerName: 'PT-210',
      printMode: PrintMode.cp1250,
      printCodePage: 45,
      receiptHeader: 'TAXI\n060 123',
      priceColor: 'crvena',
      priceScale: 150,
    );
    final back = AppSettings.fromMap(s.toMap());
    expect(back.toMap(), s.toMap());
  });

  test('neispravne sačuvane vrednosti ne obaraju čitanje', () {
    final s = AppSettings.fromMap(const {
      'eur_rate_milli': '-5',
      'waiting_speed_kmh': '500',
      'calibration_permille': 'abc',
      'gps_accuracy_m': '1',
      'language': 'de',
      'currency': 'USD',
      'selected_tariff_id': 'x',
      // stari ključevi iz v1 šeme se ignorišu
      'waiting_speed_threshold': '8.0',
    });
    expect(s.toMap(), const AppSettings().toMap());
  });

  test('validate odbija vrednosti van granica', () {
    expect(const AppSettings(waitingSpeedKmh: 0).validate(), isNotNull);
    expect(const AppSettings(waitingSpeedKmh: 51).validate(), isNotNull);
    expect(const AppSettings(gpsAccuracyM: 4).validate(), isNotNull);
    expect(const AppSettings(gpsAccuracyM: 51).validate(), isNotNull);
    expect(const AppSettings(calibrationPermille: 499).validate(), isNotNull);
    expect(const AppSettings(eurRateMilli: 0).validate(), isNotNull);
    expect(const AppSettings(language: 'de').validate(), isNotNull);
    expect(const AppSettings(currency: 'USD').validate(), isNotNull);
    expect(const AppSettings(priceColor: 'roze').validate(), isNotNull);
    expect(const AppSettings(priceScale: 250).validate(), isNotNull);
    expect(const AppSettings(priceScale: 50).validate(), isNotNull);
    expect(const AppSettings(gpsAccuracyM: 50, waitingSpeedKmh: 50).validate(), isNull);
  });

  test('bez kursa se ne upisuje ključ kursa', () {
    expect(const AppSettings().toMap().containsKey('eur_rate_milli'), false);
  });

  test('cilj zarade: čuva se, neispravan se čita kao 0, prekidač', () {
    const s = AppSettings(dailyGoal: 6000, goalEnabled: true);
    final back = AppSettings.fromMap(s.toMap());
    expect(back.dailyGoal, 6000);
    expect(back.goalEnabled, isTrue);
    expect(AppSettings.fromMap(const {'daily_goal': '-5'}).dailyGoal, 0);
    expect(AppSettings.fromMap(const {'daily_goal': 'abc'}).dailyGoal, 0);
    expect(const AppSettings().goalEnabled, isFalse);
    expect(const AppSettings(dailyGoal: -1).validate(), isNotNull);
  });

  test('omiljene adrese: čuvaju se, neispravne se preskaču', () {
    const s = AppSettings(favorites: [
      Place(label: 'Aerodrom Nikola Tesla', lat: 44.8184, lon: 20.3091),
    ]);
    final back = AppSettings.fromMap(s.toMap());
    expect(back.favorites.single.label, 'Aerodrom Nikola Tesla');
    expect(back.favorites.single.sameAs(s.favorites.single), isTrue);
    final bad = AppSettings.fromMap(const {
      'favorite_places': '[{"label":"","lat":1,"lon":1},{"label":"X","lat":999,"lon":1},'
          '{"label":"Stanica","lat":44.80,"lon":20.46},"x"]',
    });
    expect(bad.favorites.map((p) => p.label), ['Stanica']);
    expect(AppSettings.fromMap(const {'favorite_places': 'nije json'}).favorites, isEmpty);
  });
}
