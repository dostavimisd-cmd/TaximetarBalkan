abstract class SettingsRepository {
  Future<void> saveSetting(String key, String value);
  Future<String?> getSetting(String key);
  Future<Map<String, String>> getAll();

  /// Upisuje sve vrednosti u jednoj transakciji.
  Future<void> saveAll(Map<String, String> values);
}