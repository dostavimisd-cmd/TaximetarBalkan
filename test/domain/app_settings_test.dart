import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/app_settings.dart';

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
    expect(const AppSettings(gpsAccuracyM: 50, waitingSpeedKmh: 50).validate(), isNull);
  });

  test('bez kursa se ne upisuje ključ kursa', () {
    expect(const AppSettings().toMap().containsKey('eur_rate_milli'), false);
  });
}
