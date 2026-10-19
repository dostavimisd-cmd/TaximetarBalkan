import '../calibration.dart';

/// Podešavanja koja unosi korisnik. Čuvaju se u `app_settings` kao parovi
/// ključ/tekst; ovde su tipizirana i proverena. Podrazumevane vrednosti su
/// dosadašnje ponašanje aplikacije, ne tarife (Pravilo 3).
class AppSettings {
  static const String keyEurRate = 'eur_rate_milli';
  static const String keyWaitingSpeed = 'waiting_speed_kmh';
  static const String keyCalibration = 'calibration_permille';
  static const String keyGpsAccuracy = 'gps_accuracy_m';
  static const String keyLanguage = 'language';
  static const String keyCurrency = 'currency';
  static const String keySelectedTariff = 'selected_tariff_id';

  static const int defaultWaitingSpeedKmh = 8;
  static const int minWaitingSpeedKmh = 1;
  static const int maxWaitingSpeedKmh = 50;

  static const int defaultGpsAccuracyM = 15;
  static const int minGpsAccuracyM = 5;
  static const int maxGpsAccuracyM = 50;

  static const List<String> languages = ['sr', 'en'];
  static const List<String> currencies = ['RSD', 'EUR'];

  /// Kurs RSD po 1 EUR u hiljaditim delovima; null dok ga korisnik ne unese.
  final int? eurRateMilli;
  final int waitingSpeedKmh;
  final int calibrationPermille;

  /// Tačke sa lošijom procenjenom tačnošću (u metrima) se odbacuju.
  final int gpsAccuracyM;
  final String language;
  final String currency;

  /// Tarifa izabrana za sledeću vožnju; null = prva u listi.
  final int? selectedTariffId;

  const AppSettings({
    this.eurRateMilli,
    this.waitingSpeedKmh = defaultWaitingSpeedKmh,
    this.calibrationPermille = Calibration.neutralPermille,
    this.gpsAccuracyM = defaultGpsAccuracyM,
    this.language = 'sr',
    this.currency = 'RSD',
    this.selectedTariffId,
  });

  /// Čita sačuvane vrednosti; neispravna ili nepoznata vrednost daje
  /// podrazumevanu (nikad ne baca).
  factory AppSettings.fromMap(Map<String, String> m) {
    int? asInt(String key) => int.tryParse(m[key] ?? '');
    int inRange(String key, int def, int min, int max) {
      final v = asInt(key);
      return v != null && v >= min && v <= max ? v : def;
    }

    final rate = asInt(keyEurRate);
    final calibration = asInt(keyCalibration);
    return AppSettings(
      eurRateMilli: rate != null && rate > 0 ? rate : null,
      waitingSpeedKmh: inRange(keyWaitingSpeed, defaultWaitingSpeedKmh,
          minWaitingSpeedKmh, maxWaitingSpeedKmh),
      calibrationPermille: calibration != null && Calibration.isValid(calibration)
          ? calibration
          : Calibration.neutralPermille,
      gpsAccuracyM: inRange(
          keyGpsAccuracy, defaultGpsAccuracyM, minGpsAccuracyM, maxGpsAccuracyM),
      language: languages.contains(m[keyLanguage]) ? m[keyLanguage]! : 'sr',
      currency: currencies.contains(m[keyCurrency]) ? m[keyCurrency]! : 'RSD',
      selectedTariffId: asInt(keySelectedTariff),
    );
  }

  Map<String, String> toMap() => {
        if (eurRateMilli != null) keyEurRate: '$eurRateMilli',
        keyWaitingSpeed: '$waitingSpeedKmh',
        keyCalibration: '$calibrationPermille',
        keyGpsAccuracy: '$gpsAccuracyM',
        keyLanguage: language,
        keyCurrency: currency,
        if (selectedTariffId != null) keySelectedTariff: '$selectedTariffId',
      };

  /// Opis prve greške ili null ako su sva podešavanja ispravna.
  String? validate() {
    if (eurRateMilli != null && eurRateMilli! <= 0) return 'Kurs mora biti veći od 0.';
    if (waitingSpeedKmh < minWaitingSpeedKmh || waitingSpeedKmh > maxWaitingSpeedKmh) {
      return 'Brzina za čekanje: od $minWaitingSpeedKmh do $maxWaitingSpeedKmh km/h.';
    }
    if (!Calibration.isValid(calibrationPermille)) {
      return 'Kalibracija: od -50 do 50 %.';
    }
    if (gpsAccuracyM < minGpsAccuracyM || gpsAccuracyM > maxGpsAccuracyM) {
      return 'GPS tačnost: od $minGpsAccuracyM do $maxGpsAccuracyM m.';
    }
    if (!languages.contains(language)) return 'Nepoznat jezik.';
    if (!currencies.contains(currency)) return 'Nepoznata valuta.';
    return null;
  }

  AppSettings copyWith({
    int? eurRateMilli,
    int? waitingSpeedKmh,
    int? calibrationPermille,
    int? gpsAccuracyM,
    String? language,
    String? currency,
    int? selectedTariffId,
  }) {
    return AppSettings(
      eurRateMilli: eurRateMilli ?? this.eurRateMilli,
      waitingSpeedKmh: waitingSpeedKmh ?? this.waitingSpeedKmh,
      calibrationPermille: calibrationPermille ?? this.calibrationPermille,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      selectedTariffId: selectedTariffId ?? this.selectedTariffId,
    );
  }
}
