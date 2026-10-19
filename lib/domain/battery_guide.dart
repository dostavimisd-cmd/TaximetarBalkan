/// Grupa proizvođača telefona za uputstvo o radu u pozadini.
/// Čista logika (bez Fluttera); tekstovi uputstva su u prikazu.
enum BatteryGroup { samsung, xiaomi, honor, motorola, lenovo, other }

BatteryGroup batteryGroupFor(String manufacturer) {
  final m = manufacturer.trim().toLowerCase();
  if (m.contains('samsung')) return BatteryGroup.samsung;
  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
    return BatteryGroup.xiaomi;
  }
  if (m.contains('honor') || m.contains('huawei')) return BatteryGroup.honor;
  if (m.contains('motorola')) return BatteryGroup.motorola;
  if (m.contains('lenovo')) return BatteryGroup.lenovo;
  return BatteryGroup.other;
}
