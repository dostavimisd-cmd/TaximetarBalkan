import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/holiday.dart';
import 'package:taksimetar_balkan/domain/models/tariff.dart';
import 'package:taksimetar_balkan/domain/models/tariff_schedule.dart';
import 'package:taksimetar_balkan/domain/tariff_selector.dart';

const int mon = 1 << 0, tue = 1 << 1, fri = 1 << 4, sat = 1 << 5, sun = 1 << 6;
int at(int h, int m) => h * 60 + m;

// 2026-10-19 je ponedeljak
DateTime local(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m);

Tariff tariff(int id, String name, [TariffSchedule? schedule]) => Tariff(
      id: id,
      name: name,
      startPrice: 100 * id,
      pricePerKm: 10,
      waitingParaPerMin: 100,
      minPrice: 0,
      schedule: schedule,
    );

void main() {
  group('TariffSchedule.matches', () {
    test('dnevni period u istom danu, kraj nije uključen', () {
      const s = TariffSchedule(days: mon, startMinute: 360, endMinute: 1320); // 06–22
      expect(s.matches(local(19, 6)), true);
      expect(s.matches(local(19, 21, 59)), true);
      expect(s.matches(local(19, 22)), false);
      expect(s.matches(local(19, 5, 59)), false);
      expect(s.matches(local(20, 12)), false); // utorak
    });

    test('preko ponoći pripada danu u kome počinje', () {
      const s = TariffSchedule(days: fri, startMinute: 1320, endMinute: 360); // pet 22–06
      expect(s.matches(local(23, 22)), true); // petak 22:00
      expect(s.matches(local(24, 2)), true); // subota 02:00 (nastavak petka)
      expect(s.matches(local(24, 6)), false); // subota 06:00
      expect(s.matches(local(24, 23)), false); // subota 23:00 (subota nije izabrana)
      expect(s.matches(local(23, 2)), false); // petak 02:00 (četvrtak nije izabran)
    });

    test('nedelja → ponedeljak preko ponoći', () {
      const s = TariffSchedule(days: sun, startMinute: 1320, endMinute: 360);
      expect(s.matches(local(26, 3)), true); // pon 03:00 posle nedelje
    });

    test('isti početak i kraj = ceo dan', () {
      const s = TariffSchedule(days: sat | sun, startMinute: 0, endMinute: 0);
      expect(s.matches(local(25, 0)), true);
      expect(s.matches(local(25, 23, 59)), true);
      expect(s.matches(local(26, 12)), false); // ponedeljak
    });

    test('bez dana nikad ne važi', () {
      const s = TariffSchedule(days: 0, startMinute: 0, endMinute: 0);
      expect(s.matches(local(19, 12)), false);
    });

    test('describe', () {
      expect(const TariffSchedule(days: TariffSchedule.allDays, startMinute: 1320, endMinute: 360).describe(),
          'svaki dan · 22:00–06:00');
      expect(const TariffSchedule(days: sat | sun, startMinute: 0, endMinute: 0).describe(),
          'S N · ceo dan');
    });

    test('validate', () {
      expect(const TariffSchedule(days: mon, startMinute: 0, endMinute: 1440).validate(), isNotNull);
      expect(const TariffSchedule(days: 0x80, startMinute: 0, endMinute: 0).validate(), isNotNull);
      expect(const TariffSchedule(days: mon | tue, startMinute: 0, endMinute: 1439).validate(), isNull);
    });
  });

  group('Holiday', () {
    test('ponavlja se svake godine ili samo jednom', () {
      const yearly = Holiday(name: 'Nova godina', month: 1, day: 1, tariffId: 2);
      final once = Holiday(name: 'Uskrs', month: 4, day: 12, year: 2026, tariffId: 2);
      expect(yearly.matches(DateTime(2027, 1, 1, 15)), true);
      expect(once.matches(DateTime(2026, 4, 12, 0, 1)), true);
      expect(once.matches(DateTime(2027, 4, 12)), false);
    });

    test('dateString tamo i nazad', () {
      const h = Holiday(name: 'x', month: 3, day: 7, tariffId: 1);
      expect(h.dateString, '03-07');
      expect(Holiday.parseDateString('03-07'), (year: null, month: 3, day: 7));
      expect(Holiday.parseDateString('2026-12-25'), (year: 2026, month: 12, day: 25));
      expect(Holiday.parseDateString('25.12.'), isNull);
    });

    test('validate datuma', () {
      expect(const Holiday(name: 'x', month: 2, day: 29, tariffId: 1).validate(), isNull);
      expect(const Holiday(name: 'x', month: 2, day: 29, year: 2027, tariffId: 1).validate(), isNotNull);
      expect(const Holiday(name: 'x', month: 4, day: 31, tariffId: 1).validate(), isNotNull);
      expect(const Holiday(name: ' ', month: 1, day: 1, tariffId: 1).validate(), isNotNull);
      expect(const Holiday(name: 'x', month: 1, day: 1, tariffId: 0).validate(), isNotNull);
    });
  });

  group('TariffSelector', () {
    final day = tariff(1, 'Dnevna');
    final night = tariff(2, 'Noćna',
        const TariffSchedule(days: TariffSchedule.allDays, startMinute: 1320, endMinute: 360));
    final sunday = tariff(3, 'Nedelja', const TariffSchedule(days: sun, startMinute: 0, endMinute: 0));
    final tariffs = [day, night, sunday];
    const newYear = Holiday(name: 'Nova godina', month: 1, day: 1, tariffId: 3);

    TariffChoice? pick(DateTime t, {bool auto = true, int? manual}) => TariffSelector.choose(
        tariffs: tariffs, holidays: [newYear], local: t, automatic: auto, manualTariffId: manual);

    test('bez tarifa → null', () {
      expect(
          TariffSelector.choose(
              tariffs: const [], holidays: const [], local: local(19, 12), automatic: true),
          isNull);
    });

    test('ručni režim: izabrana, ili prva ako je izabrana obrisana', () {
      expect(pick(local(19, 23), auto: false, manual: 1)!.tariff.name, 'Dnevna');
      expect(pick(local(19, 23), auto: false, manual: 99)!.reason, TariffChoiceReason.fallback);
    });

    test('automatski: raspored', () {
      expect(pick(local(19, 23), manual: 1)!.tariff.name, 'Noćna');
      expect(pick(local(19, 23), manual: 1)!.reason, TariffChoiceReason.schedule);
    });

    test('automatski: kad nijedan raspored ne važi → ručni izbor', () {
      final c = pick(local(19, 12), manual: 1)!;
      expect(c.tariff.name, 'Dnevna');
      expect(c.reason, TariffChoiceReason.manual);
    });

    test('automatski: kad se poklapaju, važi prva na listi', () {
      // nedelja 23:00: i Noćna (svaki dan) i Nedelja (ceo dan); Noćna je prva
      expect(pick(local(25, 23))!.tariff.name, 'Noćna');
      expect(pick(local(25, 12))!.tariff.name, 'Nedelja');
    });

    test('automatski: praznik ima prednost nad rasporedom', () {
      final c = pick(DateTime(2027, 1, 1, 23), manual: 1)!;
      expect(c.tariff.name, 'Nedelja');
      expect(c.reason, TariffChoiceReason.holiday);
      expect(c.holiday!.name, 'Nova godina');
    });

    test('praznik sa obrisanom tarifom se preskače', () {
      final c = TariffSelector.choose(
        tariffs: [day],
        holidays: const [Holiday(name: 'x', month: 1, day: 1, tariffId: 3)],
        local: DateTime(2027, 1, 1, 12),
        automatic: true,
      )!;
      expect(c.tariff.name, 'Dnevna');
    });
  });

  test('opisi na engleskom (raspored, praznik)', () {
    const s = TariffSchedule(days: TariffSchedule.allDays, startMinute: 1320, endMinute: 360);
    expect(s.describe(english: true), 'every day · 22:00–06:00');
    expect(const TariffSchedule(days: sat | sun, startMinute: 0, endMinute: 0).describe(english: true),
        'S S · all day');
    expect(const TariffSchedule(days: 0, startMinute: 0, endMinute: 0).describe(english: true), 'no schedule');
    expect(const Holiday(name: 'x', month: 1, day: 7, tariffId: 1).describe(english: true), '07.01. (every year)');
    expect(const Holiday(name: 'x', month: 1, day: 7, tariffId: 1).describe(), '07.01. (svake godine)');
  });
}
