import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'tariffs_provider.dart';

/// Sva podešavanja korisnika; čitaju se jednom i čuvaju u `app_settings`.
class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<AppSettings> build() async => AppSettings.fromMap(await _repo.getAll());

  /// Proverava i čuva; baca ArgumentError sa opisom ako nešto nije ispravno.
  Future<void> save(AppSettings settings) async {
    final error = settings.validate();
    if (error != null) throw ArgumentError(error);
    await _repo.saveAll(settings.toMap());
    state = AsyncData(settings);
  }

  Future<void> change(AppSettings Function(AppSettings current) edit) async {
    final current = state.value ?? await future;
    await save(edit(current));
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
