import 'models/holiday.dart';
import 'models/tariff.dart';

/// Razlog zašto je tarifa izabrana (za prikaz vozaču).
enum TariffChoiceReason { manual, holiday, schedule, fallback }

class TariffChoice {
  final Tariff tariff;
  final TariffChoiceReason reason;
  final Holiday? holiday;

  const TariffChoice(this.tariff, this.reason, {this.holiday});
}

/// Bira tarifu za start vožnje. Tarifa se ne menja tokom vožnje (odluka
/// korisnika); ovde se bira samo jednom, u trenutku starta.
///
/// Automatski režim: praznik (ceo dan) → prva tarifa na listi čiji raspored
/// važi → ručni izbor → prva tarifa.
class TariffSelector {
  static TariffChoice? choose({
    required List<Tariff> tariffs,
    required List<Holiday> holidays,
    required DateTime local,
    required bool automatic,
    int? manualTariffId,
  }) {
    if (tariffs.isEmpty) return null;
    Tariff? byId(int? id) => tariffs.where((t) => t.id == id).firstOrNull;

    final manual = byId(manualTariffId);
    if (!automatic) {
      return manual != null
          ? TariffChoice(manual, TariffChoiceReason.manual)
          : TariffChoice(tariffs.first, TariffChoiceReason.fallback);
    }

    for (final h in holidays) {
      final t = byId(h.tariffId);
      if (t != null && h.matches(local)) {
        return TariffChoice(t, TariffChoiceReason.holiday, holiday: h);
      }
    }
    for (final t in tariffs) {
      if (t.schedule?.matches(local) ?? false) {
        return TariffChoice(t, TariffChoiceReason.schedule);
      }
    }
    return manual != null
        ? TariffChoice(manual, TariffChoiceReason.manual)
        : TariffChoice(tariffs.first, TariffChoiceReason.fallback);
  }
}
