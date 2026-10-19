import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Izgovara kratke najave (cena na kraju vožnje) sintetizatorom telefona.
/// Ako srpski glas nije instaliran, koristi se hrvatski/bosanski, pa engleski.
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init(String language) async {
    if (_ready) return;
    final candidates = language == 'en'
        ? const ['en-US', 'en-GB']
        : const ['sr-RS', 'sr-Latn-RS', 'hr-HR', 'bs-BA', 'en-US'];
    for (final c in candidates) {
      if (await _tts.isLanguageAvailable(c) == true) {
        await _tts.setLanguage(c);
        break;
      }
    }
    await _tts.setSpeechRate(0.5);
    _ready = true;
  }

  Future<void> speak(String text, {String language = 'sr'}) async {
    try {
      await _init(language);
      await _tts.speak(text);
    } catch (_) {
      // govor nije ključan za rad taksimetra
    }
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
