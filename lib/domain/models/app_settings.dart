import '../calibration.dart';
import '../price_throttle.dart';
import '../printing/escpos.dart';
import 'extra_charge.dart';

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
  static const String keyVoice = 'voice_announce';
  static const String keyPriceRefresh = 'price_refresh_s';
  static const String keyKeepScreenOn = 'keep_screen_on';
  static const String keyPriceColor = 'price_color';
  static const String keyPriceScale = 'price_scale';
  static const String keyDisclaimer = 'disclaimer_accepted';
  static const String keyBatteryGuide = 'battery_guide_shown';
  static const String keyButtonFeedback = 'button_feedback';
  static const String keyAutoPrint = 'auto_print';
  static const String keyExtras = 'extras';
  static const String keyDailyGoal = 'daily_goal';
  static const String keyGoalEnabled = 'goal_enabled';

  /// Gornja granica cilja zarade (tehnička, protiv pogrešnog unosa).
  static const int maxDailyGoal = 10000000;

  /// Boje cene kao na taksimetrima (LED displeji); prikaz je u UI sloju.
  static const List<String> priceColors = ['bela', 'crvena', 'zelena', 'plava', 'zuta', 'narandzasta'];
  static const int minPriceScale = 60;
  static const int maxPriceScale = 200;

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

  /// Glasovna najava cene na kraju vožnje.
  final bool voiceAnnounce;

  /// Osvežavanje cene na ekranu tokom vožnje (s): 1 (odmah), 4, 6 ili 10.
  final int priceRefreshSeconds;

  /// Ekran ne gasi dok je aplikacija otvorena (cena se stalno vidi).
  final bool keepScreenOn;

  /// Boja cene na glavnom ekranu (jedna od [priceColors]).
  final String priceColor;

  /// Veličina cene u procentima (60–200); cena se ipak smanjuje ako nema mesta.
  final int priceScale;

  /// Korisnik je prihvatio napomenu pri prvom pokretanju (nije overeni taksimetar).
  final bool disclaimerAccepted;

  /// Uputstvo za rad u pozadini je već prikazano pri prvom pokretanju.
  final bool batteryGuideShown;

  /// Vibracija i zvuk kad vožnja počne, stane na pauzu, nastavi se ili završi.
  final bool buttonFeedback;

  /// Račun se sam šalje na izabrani štampač kad se vožnja završi.
  final bool autoPrint;

  /// Spisak doplata za dugme „+” tokom vožnje (naziv + iznos); unosi korisnik.
  final List<ExtraCharge> extras;

  /// Cilj zarade (din) za smenu/dan; 0 = nije postavljen. Unosi vozač.
  final int dailyGoal;

  /// Traka napretka ka cilju na glavnom ekranu (motivacija), uključi/isključi.
  final bool goalEnabled;

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
    this.voiceAnnounce = false,
    this.priceRefreshSeconds = 1,
    this.keepScreenOn = true,
    this.priceColor = 'bela',
    this.priceScale = 100,
    this.disclaimerAccepted = false,
    this.batteryGuideShown = false,
    this.buttonFeedback = true,
    this.autoPrint = false,
    this.extras = const [],
    this.dailyGoal = 0,
    this.goalEnabled = false,
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
      voiceAnnounce: m[keyVoice] == '1',
      priceRefreshSeconds: PriceThrottle.allowedSeconds.contains(asInt(keyPriceRefresh))
          ? asInt(keyPriceRefresh)!
          : 1,
      keepScreenOn: m[keyKeepScreenOn] != '0',
      priceColor: priceColors.contains(m[keyPriceColor]) ? m[keyPriceColor]! : 'bela',
      priceScale: inRange(keyPriceScale, 100, minPriceScale, maxPriceScale),
      disclaimerAccepted: m[keyDisclaimer] == '1',
      batteryGuideShown: m[keyBatteryGuide] == '1',
      buttonFeedback: m[keyButtonFeedback] != '0',
      autoPrint: m[keyAutoPrint] == '1',
      extras: ExtraCharge.decodeList(m[keyExtras]),
      dailyGoal: inRange(keyDailyGoal, 0, 0, maxDailyGoal),
      goalEnabled: m[keyGoalEnabled] == '1',
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
        keyVoice: voiceAnnounce ? '1' : '0',
        keyPriceRefresh: '$priceRefreshSeconds',
        keyKeepScreenOn: keepScreenOn ? '1' : '0',
        keyPriceColor: priceColor,
        keyPriceScale: '$priceScale',
        keyDisclaimer: disclaimerAccepted ? '1' : '0',
        keyBatteryGuide: batteryGuideShown ? '1' : '0',
        keyButtonFeedback: buttonFeedback ? '1' : '0',
        keyAutoPrint: autoPrint ? '1' : '0',
        keyExtras: ExtraCharge.encodeList(extras),
        keyDailyGoal: '$dailyGoal',
        keyGoalEnabled: goalEnabled ? '1' : '0',
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
    if (!PriceThrottle.allowedSeconds.contains(priceRefreshSeconds)) {
      return 'Osvežavanje cene: 1, 4, 6 ili 10 s.';
    }
    if (!priceColors.contains(priceColor)) return 'Nepoznata boja cene.';
    if (priceScale < minPriceScale || priceScale > maxPriceScale) {
      return 'Veličina cene: od $minPriceScale do $maxPriceScale %.';
    }
    if (receiptHeader.length > 500) return 'Zaglavlje računa je predugačko.';
    if (dailyGoal < 0 || dailyGoal > maxDailyGoal) return 'Neispravan cilj zarade.';
    if (extras.length > ExtraCharge.maxCount) {
      return 'Najviše ${ExtraCharge.maxCount} doplata.';
    }
    for (final e in extras) {
      final error = e.validate();
      if (error != null) return error;
    }
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
    bool? voiceAnnounce,
    int? priceRefreshSeconds,
    bool? keepScreenOn,
    String? priceColor,
    int? priceScale,
    bool? disclaimerAccepted,
    bool? batteryGuideShown,
    bool? buttonFeedback,
    bool? autoPrint,
    List<ExtraCharge>? extras,
    int? dailyGoal,
    bool? goalEnabled,
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
      voiceAnnounce: voiceAnnounce ?? this.voiceAnnounce,
      priceRefreshSeconds: priceRefreshSeconds ?? this.priceRefreshSeconds,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      priceColor: priceColor ?? this.priceColor,
      priceScale: priceScale ?? this.priceScale,
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      batteryGuideShown: batteryGuideShown ?? this.batteryGuideShown,
      buttonFeedback: buttonFeedback ?? this.buttonFeedback,
      autoPrint: autoPrint ?? this.autoPrint,
      extras: extras ?? this.extras,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      goalEnabled: goalEnabled ?? this.goalEnabled,
    );
  }
}
