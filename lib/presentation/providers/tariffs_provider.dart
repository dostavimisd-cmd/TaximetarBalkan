import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database_helper.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/tariff_repository_impl.dart';
import '../../domain/models/tariff.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/tariff_repository.dart';


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
