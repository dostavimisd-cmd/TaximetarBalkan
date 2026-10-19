import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/printing/dither.dart';

void main() {
  test('belo ostaje belo, crno ostaje crno', () {
    expect(Dither.floydSteinberg(4, 1, [255, 255, 255, 255]), everyElement(false));
    expect(Dither.floydSteinberg(4, 1, [0, 0, 0, 0]), everyElement(true));
  });

  test('srednje sivo daje približno pola crnih tačaka', () {
    const w = 32, h = 32;
    final out = Dither.floydSteinberg(w, h, List.filled(w * h, 128));
    final black = out.where((b) => b).length;
    expect(black, inInclusiveRange(w * h * 0.4, w * h * 0.6));
  });

  test('svetlije sivo daje manje crnih tačaka od tamnijeg', () {
    const w = 32, h = 32;
    int blacks(int v) => Dither.floydSteinberg(w, h, List.filled(w * h, v)).where((b) => b).length;
    expect(blacks(200), lessThan(blacks(60)));
  });

  test('pogrešan broj piksela → greška', () {
    expect(() => Dither.floydSteinberg(2, 2, [0]), throwsArgumentError);
  });

  test('centerOnWidth dodaje beli rub sa obe strane', () {
    final out = Dither.centerOnWidth(2, 1, [true, true], 6);
    expect(out, [false, false, true, true, false, false]);
    expect(Dither.centerOnWidth(3, 1, [true, false, true], 2), [true, false, true]);
  });
}
