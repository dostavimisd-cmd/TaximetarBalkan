/// ESC/POS komande za termalne štampače računa (58 mm, npr. GOOJPRT PT-210).
/// Čista Dart logika: bajtovi se šalju štampaču preko Bluetooth-a.
///
/// Naša slova (č ć ž š đ) jeftini štampači podržavaju samo uz pravu kodnu
/// stranu, čiji broj (ESC t n) zavisi od firmvera. Zato postoje režimi:
/// - [PrintMode.image]: račun se šalje kao slika — slova su uvek tačna;
/// - [PrintMode.cp852] / [PrintMode.cp1250]: tekst u kodnoj strani, broj
///   strane bira korisnik posle probne štampe;
/// - [PrintMode.plain]: bez kvačica (c, c, z, s, dj) — radi na svakom štampaču.
enum PrintMode { image, cp852, cp1250, plain }

class EscPos {
  static const int dotsPerLine = 384; // 58 mm, 203 dpi
  static const int charsPerLine = 32; // font A 12×24

  static const List<int> init = [0x1B, 0x40];

  static List<int> codePage(int n) => [0x1B, 0x74, n];

  /// 0 levo, 1 centar, 2 desno
  static List<int> align(int a) => [0x1B, 0x61, a];

  static List<int> bold(bool on) => [0x1B, 0x45, on ? 1 : 0];

  /// Dvostruka širina i visina (16 znakova u redu) ili normalno.
  static List<int> large(bool on) => [0x1D, 0x21, on ? 0x11 : 0x00];

  static List<int> feed(int lines) => [0x1B, 0x64, lines.clamp(0, 255)];

  static const Map<String, int> _cp852 = {
    'č': 0x9F, 'Č': 0xAC, 'ć': 0x86, 'Ć': 0x8F, 'ž': 0xA7, 'Ž': 0xA6, //
    'š': 0xE7, 'Š': 0xE6, 'đ': 0xD0, 'Đ': 0xD1,
  };

  static const Map<String, int> _cp1250 = {
    'č': 0xE8, 'Č': 0xC8, 'ć': 0xE6, 'Ć': 0xC6, 'ž': 0x9E, 'Ž': 0x8E, //
    'š': 0x9A, 'Š': 0x8A, 'đ': 0xF0, 'Đ': 0xD0,
  };

  static const Map<String, String> _latin = {
    'č': 'c', 'Č': 'C', 'ć': 'c', 'Ć': 'C', 'ž': 'z', 'Ž': 'Z', //
    'š': 's', 'Š': 'S', 'đ': 'dj', 'Đ': 'Dj',
  };

  /// č→c, ć→c, ž→z, š→s, đ→dj
  static String transliterate(String text) =>
      text.split('').map((c) => _latin[c] ?? c).join();

  /// Tekst u bajtove za dati režim; znak koji štampač ne može da prikaže
  /// postaje '?'. Za [PrintMode.image] koristi se [raster], ne ovo.
  static List<int> encode(String text, PrintMode mode) {
    final map = switch (mode) {
      PrintMode.cp852 => _cp852,
      PrintMode.cp1250 => _cp1250,
      _ => const <String, int>{},
    };
    final source = mode == PrintMode.plain ? transliterate(text) : text;
    final out = <int>[];
    for (final rune in source.runes) {
      final ch = String.fromCharCode(rune);
      if (rune >= 0x20 && rune < 0x7F) {
        out.add(rune);
      } else if (rune == 0x0A) {
        out.add(0x0A);
      } else {
        out.add(map[ch] ?? 0x3F);
      }
    }
    return out;
  }

  /// Slika 1-bit (true = crno), red po red, kao GS v 0 komande. Visina se
  /// deli na trake od [bandRows] redova, jer jeftini štampači imaju mali bafer.
  static List<int> raster(int width, int height, List<bool> pixels, {int bandRows = 128}) {
    if (pixels.length != width * height) {
      throw ArgumentError('Pogrešan broj piksela: ${pixels.length} != ${width * height}');
    }
    final bytesPerRow = (width + 7) ~/ 8;
    final out = <int>[];
    for (var top = 0; top < height; top += bandRows) {
      final rows = (height - top) < bandRows ? height - top : bandRows;
      out.addAll([0x1D, 0x76, 0x30, 0x00, bytesPerRow & 0xFF, bytesPerRow >> 8, rows & 0xFF, rows >> 8]);
      for (var y = top; y < top + rows; y++) {
        for (var b = 0; b < bytesPerRow; b++) {
          var byte = 0;
          for (var bit = 0; bit < 8; bit++) {
            final x = b * 8 + bit;
            if (x < width && pixels[y * width + x]) byte |= 0x80 >> bit;
          }
          out.add(byte);
        }
      }
    }
    return out;
  }
}
