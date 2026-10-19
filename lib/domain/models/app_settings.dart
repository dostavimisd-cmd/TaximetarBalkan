import '../calibration.dart';
import '../printing/escpos.dart';

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
  static const String keyAutoTariff = 'auto_tariff';
  static const String keyShowMap = 'show_map';
  static const String keyBackgroundLogo = 'background_logo';
  static const String keyPrinterMac = 'printer_mac';
  static const String keyPrinterName = 'printer_name';
  static const String keyPrintMode = 'print_mode';
  static const String keyPrintCodePage = 'print_codepage';
  static const String keyReceiptHeader = 'receipt_header';
  static const String keyReceiptLogo = 'receipt_logo';

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

  /// Automatski izbor tarife pri startu (praznici, pa raspored).
  final bool autoTariff;

  /// Mapa (OpenStreetMap) na glavnom ekranu; traži internet za podloge.
  final bool showMap;

  /// Putanja do slike logoa za pozadinu; null = crna pozadina.
  final String? backgroundLogoPath;

  /// Upareni Bluetooth štampač računa; null = nije izabran.
  final String? printerMac;
  final String? printerName;

  /// Kako se štampaju naša slova (videti [PrintMode]); podrazumevano slika.
  final PrintMode printMode;

  /// Broj kodne strane (ESC t n) za tekstualni režim; bira se probnom štampom.
  final int printCodePage;

  /// Zaglavlje računa (naziv, telefon…), red po red; unosi korisnik.
  final String receiptHeader;

  /// Slika logoa firme na vrhu računa; null = bez logoa.
  final String? receiptLogoPath;

  const AppSettings({
    this.eurRateMilli,
    this.waitingSpeedKmh = defaultWaitingSpeedKmh,
    this.calibrationPermille = Calibration.neutralPermille,
    this.gpsAccuracyM = defaultGpsAccuracyM,
    this.language = 'sr',
    this.currency = 'RSD',
    this.selectedTariffId,
    this.autoTariff = false,
    this.showMap = true,
    this.backgroundLogoPath,
    this.printerMac,
    this.printerName,
    this.printMode = PrintMode.image,
    this.printCodePage = 18,
    this.receiptHeader = '',
    this.receiptLogoPath,
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
      autoTariff: m[keyAutoTariff] == '1',
      showMap: m[keyShowMap] != '0',
      backgroundLogoPath:
          (m[keyBackgroundLogo] ?? '').isEmpty ? null : m[keyBackgroundLogo],
      printerMac: (m[keyPrinterMac] ?? '').isEmpty ? null : m[keyPrinterMac],
      printerName: (m[keyPrinterName] ?? '').isEmpty ? null : m[keyPrinterName],
      printMode: PrintMode.values
              .where((v) => v.name == m[keyPrintMode])
              .firstOrNull ??
          PrintMode.image,
      printCodePage: inRange(keyPrintCodePage, 18, 0, 255),
      receiptHeader: m[keyReceiptHeader] ?? '',
      receiptLogoPath: (m[keyReceiptLogo] ?? '').isEmpty ? null : m[keyReceiptLogo],
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
        keyAutoTariff: autoTariff ? '1' : '0',
        keyShowMap: showMap ? '1' : '0',
        // prazno = crna pozadina (upis prazne vrednosti briše raniji logo)
        keyBackgroundLogo: backgroundLogoPath ?? '',
        keyPrinterMac: printerMac ?? '',
        keyPrinterName: printerName ?? '',
        keyPrintMode: printMode.name,
        keyPrintCodePage: '$printCodePage',
        keyReceiptHeader: receiptHeader,
        keyReceiptLogo: receiptLogoPath ?? '',
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
    if (printCodePage < 0 || printCodePage > 255) return 'Neispravna kodna strana.';
    if (receiptHeader.length > 500) return 'Zaglavlje računa je predugačko.';
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
    bool? autoTariff,
    bool? showMap,
    String? backgroundLogoPath,
    bool clearBackgroundLogo = false,
    String? printerMac,
    String? printerName,
    PrintMode? printMode,
    int? printCodePage,
    String? receiptHeader,
    String? receiptLogoPath,
    bool clearReceiptLogo = false,
  }) {
    return AppSettings(
      eurRateMilli: eurRateMilli ?? this.eurRateMilli,
      waitingSpeedKmh: waitingSpeedKmh ?? this.waitingSpeedKmh,
      calibrationPermille: calibrationPermille ?? this.calibrationPermille,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      selectedTariffId: selectedTariffId ?? this.selectedTariffId,
      autoTariff: autoTariff ?? this.autoTariff,
      showMap: showMap ?? this.showMap,
      backgroundLogoPath: clearBackgroundLogo
          ? null
          : (backgroundLogoPath ?? this.backgroundLogoPath),
      printerMac: printerMac ?? this.printerMac,
      printerName: printerName ?? this.printerName,
      printMode: printMode ?? this.printMode,
      printCodePage: printCodePage ?? this.printCodePage,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptLogoPath: clearReceiptLogo ? null : (receiptLogoPath ?? this.receiptLogoPath),
    );
  }
}
