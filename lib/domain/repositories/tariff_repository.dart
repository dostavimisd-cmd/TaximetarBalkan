import '../models/tariff.dart';

abstract class TariffRepository {
  Future<List<Tariff>> getAll();

  /// Upisuje novu tarifu (id == 0) ili menja postojeću. Vraća id.
  Future<int> save(Tariff tariff);

  Future<void> delete(int id);
}
