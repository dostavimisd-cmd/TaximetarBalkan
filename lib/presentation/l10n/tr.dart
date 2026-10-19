import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'en.dart';

/// Prevod korisničkih tekstova. Ključ je srpski tekst (pa je kod čitljiv),
/// a za engleski se uzima [enStrings]. Mesta za vrednosti su {0}, {1}…:
///   t('Greška: {0}', [e])
/// Tekst bez prevoda ostaje na srpskom (test proverava da takvih nema).
class Tr {
  final bool english;
  const Tr(this.english);

  String call(String sr, [List<Object?> args = const []]) {
    var text = english ? (enStrings[sr] ?? sr) : sr;
    for (var i = 0; i < args.length; i++) {
      text = text.replaceAll('{$i}', '${args[i]}');
    }
    return text;
  }
}

final trProvider = Provider<Tr>((ref) {
  final lang = ref.watch(appSettingsProvider).value?.language ?? 'sr';
  return Tr(lang == 'en');
});
