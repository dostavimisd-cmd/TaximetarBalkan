import 'models/fixed_route.dart';

class ImportIssue {
  final int line; // 1-based
  final String text;
  final String reason;

  const ImportIssue(this.line, this.text, this.reason);
}

class ImportResult {
  final List<FixedRoute> routes;
  final List<ImportIssue> issues;

  const ImportResult(this.routes, this.issues);
}

/// Uvoz fiksnih relacija iz nalepljenog teksta, red po red. Podržano:
///   Naziv ; Od ; Do ; Cena
///   Naziv ; Cena
///   Naziv - Cena           (zadnja crta ili tabulator razdvajaju cenu)
/// Cena može biti "2500", "2.500", "2 500", "2500 din", "2500 RSD".
/// Prazni redovi i naslovi (red bez cene) se prijavljuju, ne uvoze.
class FixedRouteImport {
  static int? parsePrice(String raw) {
    var t = raw
        .toLowerCase()
        .replaceAll(RegExp(r'(rsd|din\.?|dinara|dinar)'), '')
        .replaceAll(RegExp(r'\s'), '');
    // Decimale (jedna ili dve cifre posle poslednjeg . ili ,): dozvoljene su
    // samo nule ("2.500,00" = 2500); inače cena nije ceo dinar → odbija se.
    // Tri cifre posle tačke su razdvajanje hiljada ("2.500").
    final dec = RegExp(r'^(.*\d)[.,](\d{1,2})$').firstMatch(t);
    if (dec != null) {
      if (RegExp(r'[^0]').hasMatch(dec.group(2)!)) return null;
      t = dec.group(1)!;
    }
    t = t.replaceAll(RegExp(r'[.,]'), '');
    if (!RegExp(r'^\d{1,7}$').hasMatch(t)) return null;
    final v = int.parse(t);
    return v > 0 ? v : null;
  }

  static ImportResult parse(String text) {
    final routes = <FixedRoute>[];
    final issues = <ImportIssue>[];
    final lines = text.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      List<String> parts;
      if (line.contains(';') || line.contains('\t')) {
        parts = line.split(RegExp(r'[;\t]')).map((p) => p.trim()).toList();
      } else {
        final m = RegExp(r'^(.*\S)\s+[-–—]\s+(\S.*)$').firstMatch(line);
        if (m == null) {
          issues.add(ImportIssue(i + 1, line, 'nema cene (očekujem "Naziv - cena" ili "Naziv; cena")'));
          continue;
        }
        parts = [m.group(1)!, m.group(2)!];
      }

      final price = parsePrice(parts.last);
      if (price == null) {
        issues.add(ImportIssue(i + 1, line, 'cena nije ceo broj'));
        continue;
      }
      final fields = parts.sublist(0, parts.length - 1).where((p) => p.isNotEmpty).toList();
      if (fields.isEmpty) {
        issues.add(ImportIssue(i + 1, line, 'nedostaje naziv'));
        continue;
      }
      final route = switch (fields.length) {
        1 => FixedRoute(name: fields[0], price: price),
        2 => FixedRoute(name: '${fields[0]} - ${fields[1]}', fromLabel: fields[0], toLabel: fields[1], price: price),
        _ => FixedRoute(name: fields[0], fromLabel: fields[1], toLabel: fields[2], price: price),
      };
      final error = route.validate();
      if (error != null) {
        issues.add(ImportIssue(i + 1, line, error));
        continue;
      }
      routes.add(route);
    }
    return ImportResult(routes, issues);
  }

  /// Za pretragu: mala slova, bez kvačica (č→c, đ→dj...), da "djerdap" nađe "Đerdap".
  static String fold(String s) {
    const map = {'č': 'c', 'ć': 'c', 'ž': 'z', 'š': 's', 'đ': 'dj'};
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      b.write(map[ch] ?? ch);
    }
    return b.toString();
  }

  /// Relacije čiji naziv/od/do sadrže sve reči upita (bez obzira na kvačice).
  static List<FixedRoute> search(List<FixedRoute> routes, String query) {
    final words = fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return routes;
    return routes.where((r) {
      final hay = fold('${r.name} ${r.fromLabel} ${r.toLabel}');
      return words.every(hay.contains);
    }).toList();
  }
}
