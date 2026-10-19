import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/battery_guide.dart';
import 'package:taksimetar_balkan/domain/models/app_settings.dart';

void main() {
  test('proizvođač telefona se razvrstava u grupu uputstva', () {
    expect(batteryGroupFor('samsung'), BatteryGroup.samsung);
    expect(batteryGroupFor('Xiaomi'), BatteryGroup.xiaomi);
    expect(batteryGroupFor('Redmi'), BatteryGroup.xiaomi);
    expect(batteryGroupFor('HONOR'), BatteryGroup.honor);
    expect(batteryGroupFor('HUAWEI'), BatteryGroup.honor);
    expect(batteryGroupFor('motorola'), BatteryGroup.motorola);
    expect(batteryGroupFor('LENOVO'), BatteryGroup.lenovo);
    expect(batteryGroupFor('Google'), BatteryGroup.other);
    expect(batteryGroupFor(''), BatteryGroup.other);
  });

  test('napomena i uputstvo: podrazumevano nisu prihvaćeni, čuvaju se', () {
    final fresh = AppSettings.fromMap(const {});
    expect(fresh.disclaimerAccepted, isFalse);
    expect(fresh.batteryGuideShown, isFalse);
    final saved = AppSettings.fromMap(
      fresh.copyWith(disclaimerAccepted: true, batteryGuideShown: true).toMap(),
    );
    expect(saved.disclaimerAccepted, isTrue);
    expect(saved.batteryGuideShown, isTrue);
  });
}
