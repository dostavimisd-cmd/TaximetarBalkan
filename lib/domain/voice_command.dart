/// Glasovna komanda vožnje (G4). Izvršava se tek posle potvrde vozača.
enum VoiceCommand { start, pause, resume, stop }

/// Prepoznaje komandu u izgovorenom tekstu (srpski latinicom ili ćirilicom,
/// engleski). Više komandi ili nijedna → null (bolje ništa nego pogrešno).
class VoiceCommands {
  static const Map<VoiceCommand, List<String>> _words = {
    VoiceCommand.start: ['start', 'startuj', 'kreni', 'pokreni', 'počni', 'pocni', 'старт', 'крени', 'покрени', 'почни'],
    VoiceCommand.pause: ['pauza', 'pauziraj', 'pause', 'пауза', 'паузирај'],
    VoiceCommand.resume: ['nastavi', 'nastavak', 'resume', 'continue', 'настави', 'наставак'],
    VoiceCommand.stop: ['kraj', 'završi', 'zavrsi', 'stop', 'stani', 'end', 'finish', 'крај', 'заврши', 'стоп'],
  };

  static VoiceCommand? parse(String text) {
    final words = text
        .toLowerCase()
        .split(RegExp(r'[^a-zčćžšđа-яђјљњћџ]+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    final found = {
      for (final e in _words.entries)
        if (e.value.any(words.contains)) e.key,
    };
    return found.length == 1 ? found.single : null;
  }
}
