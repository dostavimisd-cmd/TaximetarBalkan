import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database_helper.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/tariff_repository_impl.dart';
import '../../domain/models/tariff.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/tariff_repository.dart';

const String eurRateSettingKey = 'eur_rate_milli';

final tariffRepositoryProvider = Provider<TariffRepository>(
  (ref) => TariffRepositoryImpl(() => DatabaseHelper.instance.database),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(DatabaseHelper.instance),
);

/// Tarife koje je korisnik uneo (nema ugrađenih — Pravilo 3).
class TariffsNotifier extends AsyncNotifier<List<Tariff>> {
  TariffRepository get _repo => ref.read(tariffRepositoryProvider);

  @override
  Future<List<Tariff>> build() => _repo.getAll();

  Future<int> save(Tariff tariff) async {
    final id = await _repo.save(tariff);
    state = AsyncData(await _repo.getAll());
    return id;
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    state = AsyncData(await _repo.getAll());
  }
}

final tariffsProvider =
    AsyncNotifierProvider<TariffsNotifier, List<Tariff>>(TariffsNotifier.new);

/// Kurs RSD po 1 EUR u hiljaditim delovima; null dok ga korisnik ne unese.
class EurRateNotifier extends AsyncNotifier<int?> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<int?> build() async {
    final value = await _repo.getSetting(eurRateSettingKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<void> set(int rateMilli) async {
    await _repo.saveSetting(eurRateSettingKey, '$rateMilli');
    state = AsyncData(rateMilli);
  }
}

final eurRateProvider =
    AsyncNotifierProvider<EurRateNotifier, int?>(EurRateNotifier.new);
