import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/price_throttle.dart';

void main() {
  test('prva vrednost se prikazuje odmah', () {
    expect(PriceThrottle().show(250, 0, 6000), 250);
  });

  test('nova cena tek posle intervala od poslednje promene prikaza', () {
    final t = PriceThrottle();
    expect(t.show(250, 0, 6000), 250);
    expect(t.show(260, 1000, 6000), 250);
    expect(t.show(270, 5999, 6000), 250);
    expect(t.show(280, 6000, 6000), 280);
    expect(t.show(290, 7000, 6000), 280);
    expect(t.show(290, 12000, 6000), 290);
  });

  test('force prikazuje odmah (početak i kraj vožnje)', () {
    final t = PriceThrottle();
    t.show(250, 0, 10000);
    expect(t.show(1279, 1000, 10000, force: true), 1279);
  });

  test('interval 1 s ≈ odmah pri osvežavanju svake sekunde', () {
    final t = PriceThrottle();
    t.show(250, 0, 1000);
    expect(t.show(260, 1000, 1000), 260);
  });
}
