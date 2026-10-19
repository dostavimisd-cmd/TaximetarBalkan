/// Pretvaranje slike u crno-belo za termalni štampač.
class Dither {
  /// Floyd–Steinberg: siva polja logoa postaju raster tačaka umesto da
  /// nestanu ili se slepe u crno. [lum] je svetlina 0–255 po pikselu (red po
  /// red); rezultat: true = crna tačka.
  static List<bool> floydSteinberg(int width, int height, List<int> lum) {
    if (lum.length != width * height) {
      throw ArgumentError('Pogrešan broj piksela: ${lum.length} != ${width * height}');
    }
    final buf = List<int>.of(lum);
    final out = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        final old = buf[i].clamp(0, 255);
        final black = old < 128;
        out[i] = black;
        final err = old - (black ? 0 : 255);
        if (x + 1 < width) buf[i + 1] += err * 7 ~/ 16;
        if (y + 1 < height) {
          if (x > 0) buf[i + width - 1] += err * 3 ~/ 16;
          buf[i + width] += err * 5 ~/ 16;
          if (x + 1 < width) buf[i + width + 1] += err ~/ 16;
        }
      }
    }
    return out;
  }

  /// Centrira sliku na punu širinu štampača (beli rub levo i desno).
  static List<bool> centerOnWidth(int width, int height, List<bool> pixels, int targetWidth) {
    if (width >= targetWidth) return pixels;
    final left = (targetWidth - width) ~/ 2;
    final out = List<bool>.filled(targetWidth * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        out[y * targetWidth + left + x] = pixels[y * width + x];
      }
    }
    return out;
  }
}
