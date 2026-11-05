import 'package:flutter/services.dart';

/// Mali most ka Androidu (MainActivity): proizvođač telefona i sistemski ekran
/// optimizacije baterije. Van Androida (testovi) vraća prazno/false.
class DeviceService {
  static const _channel = MethodChannel('rs.taksimetar.balkan/device');

  static Future<String> manufacturer() async {
    try {
      return await _channel.invokeMethod<String>('manufacturer') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Vibracija po šablonu (pauza, vibracija, … u ms); false ako nije moguća
  /// (tada pozivalac koristi vibraciju dodira).
  static Future<bool> vibrate(List<int> pattern) async {
    try {
      return await _channel.invokeMethod<bool>('vibrate', {'pattern': pattern}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Sistemski glasovni unos (onaj koji je podešen na telefonu). Vraća
  /// izgovoreni tekst, null ako je korisnik odustao; baca ako unos ne postoji.
  static Future<String?> voiceInput({String language = 'sr-RS'}) =>
      _channel.invokeMethod<String>('voiceInput', {'language': language});

  /// Fajl u Download/TaksimetarBalkan (Android 10+), uz čuvanje samo [keep]
  /// najnovijih kopija; false ako nije moguće (stariji Android, iOS).
  static Future<bool> saveToDownloads(String name, Uint8List bytes, {int keep = 7}) async {
    try {
      return await _channel.invokeMethod<bool>(
            'saveDownload',
            {'name': name, 'bytes': bytes, 'keep': keep},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Otvara sistemski spisak optimizacije baterije; false ako nije uspelo.
  static Future<bool> openBatterySettings() async {
    try {
      return await _channel.invokeMethod<bool>('openBatterySettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
