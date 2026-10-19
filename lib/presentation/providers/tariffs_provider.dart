import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database_helper.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/tariff_repository_impl.dart';
import '../../data/services/ride_engine.dart';
import '../../domain/calibration.dart';
import '../../domain/models/tariff.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/tariff_repository.dart';

const String eurRateSettingKey = 'eur_rate_milli';
const String waitingSpeedSettingKey = 'waiting_speed_kmh';
const String calibrationSettingKey = 'calibration_permille';

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

/// Brzina (km/h) ispod koje se računa čekanje. Korisnik je podešava;
/// dok je ne promeni, važi dosadašnjih 8 km/h.
class WaitingSpeedNotifier extends AsyncNotifier<int> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<int> build() async {
    final value = await _repo.getSetting(waitingSpeedSettingKey);
    return int.tryParse(value ?? '') ?? RideEngine.defaultWaitingSpeedKmh;
  }

  Future<void> set(int kmh) async {
    await _repo.saveSetting(waitingSpeedSettingKey, '$kmh');
    state = AsyncData(kmh);
  }
}

final waitingSpeedProvider =
    AsyncNotifierProvider<WaitingSpeedNotifier, int>(WaitingSpeedNotifier.new);

/// Kalibracija distance u promilima (1000 = bez korekcije).
class CalibrationNotifier extends AsyncNotifier<int> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<int> build() async {
    final value = int.tryParse(await _repo.getSetting(calibrationSettingKey) ?? '');
    return value != null && Calibration.isValid(value)
        ? value
        : Calibration.neutralPermille;
  }

  Future<void> set(int permille) async {
    await _repo.saveSetting(calibrationSettingKey, '$permille');
    state = AsyncData(permille);
  }
}

final calibrationProvider =
    AsyncNotifierProvider<CalibrationNotifier, int>(CalibrationNotifier.new);
