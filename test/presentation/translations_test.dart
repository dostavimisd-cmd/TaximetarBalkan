import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/presentation/l10n/en.dart';
import 'package:taksimetar_balkan/presentation/l10n/tr.dart';

/// Svi tekstovi aplikacije koji idu kroz t('...') moraju imati engleski
/// prevod (aplikacija ide na Play prodavnicu). Ključevi se čitaju iz izvornog
/// koda, pa novi tekst bez prevoda obara ovaj test.
Set<String> _keysInSource() {
  final keys = <String>{};
  final callRe = RegExp(r"""\bt\(\s*'((?:[^'\\]|\\.)*)'""");
  final returnRe = RegExp(r"""return '((?:[^'\\]|\\.)*)'""");
  for (final f in Directory('lib/presentation').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final src = f.readAsStringSync();
    for (final m in callRe.allMatches(src)) {
      keys.add(m.group(1)!);
    }
    // tekstovi koji se prevode na mestu prikazа: _what (rupe u signalu) i boje cene
    final what = src.indexOf('static String _what');
    if (what >= 0) {
      final end = what + RegExp(r'\r?\n  \}\r?\n').firstMatch(src.substring(what))!.start;
      for (final m in returnRe.allMatches(src.substring(what, end))) {
        keys.add(m.group(1)!);
      }
    }
  }
  final colors = File('lib/presentation/widgets/price_colors.dart').readAsStringSync();
  final labels = colors.substring(colors.indexOf('priceColorLabels'));
  for (final m in RegExp(r"""'[a-z]+':\s*'([^']+)'""").allMatches(labels)) {
    keys.add(m.group(1)!);
  }
  return keys.map((k) => k.replaceAll(r'\n', '\n').replaceAll(r"\'", "'")).toSet();
}

void main() {
  test('svaki tekst aplikacije ima engleski prevod', () {
    final missing = _keysInSource().where((k) => !enStrings.containsKey(k)).toList()..sort();
    expect(missing, isEmpty,
        reason: 'Bez prevoda (${missing.length}):\n${missing.map((m) => "  '$m'").join('\n')}');
  });

  test('prevod zadržava ista mesta za vrednosti ({0}, {1}…)', () {
    final placeholder = RegExp(r'\{\d+\}');
    for (final e in enStrings.entries) {
      final sr = placeholder.allMatches(e.key).map((m) => m.group(0)).toSet();
      final en = placeholder.allMatches(e.value).map((m) => m.group(0)).toSet();
      expect(en, sr, reason: e.key);
      expect(e.value.trim(), isNotEmpty, reason: e.key);
    }
  });

  test('Tr: srpski vraća ključ, engleski prevod, mesta se popunjavaju', () {
    const sr = Tr(false), en = Tr(true);
    expect(sr('Podešavanja'), 'Podešavanja');
    expect(en('Podešavanja'), enStrings['Podešavanja']);
    expect(en('Greška: {0}', ['x']), contains('x'));
    expect(sr('nepoznat tekst'), 'nepoznat tekst');
  });

  test('Tr.message: cela poruka, prevod početka, srpski bez promene', () {
    const sr = Tr(false), en = Tr(true);
    expect(en.message('GPS je isključen. Uključi lokaciju na telefonu.'), 'GPS is off. Turn on location on the phone.');
    expect(en.message('Greška pri zatvaranju vožnje: SqliteException(5)'), 'Error closing the ride: SqliteException(5)');
    expect(en.message('Cene ne smeju biti negativne.'), 'Prices cannot be negative.');
    expect(en.message('already English text'), 'already English text');
    expect(sr.message('Greška pri zatvaranju vožnje: x'), 'Greška pri zatvaranju vožnje: x');
  });

  test('svaka poruka iz domena (provera unosa) ima prevod', () {
    final re = RegExp(r"return '([^'$]{8,})'");
    for (final path in [
      'lib/domain/models/tariff.dart', 'lib/domain/models/holiday.dart',
      'lib/domain/models/fixed_route.dart', 'lib/domain/models/app_settings.dart',
      'lib/domain/models/tariff_schedule.dart',
    ]) {
      for (final m in re.allMatches(File(path).readAsStringSync())) {
        final msg = m.group(1)!;
        if (!msg.endsWith('.')) continue; // samo poruke (rečenice), ne opisi
        expect(enStrings.containsKey(msg), isTrue, reason: '$path: $msg');
      }
    }
  });
}
