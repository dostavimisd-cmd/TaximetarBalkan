import '../models/fixed_route.dart';

abstract class FixedRouteRepository {
  Future<List<FixedRoute>> getAll();
  Future<int> save(FixedRoute route);
  Future<void> delete(int id);

  /// Uvoz više relacija odjednom, u jednoj transakciji. Relacija sa istim
  /// nazivom, "od" i "do" (bez obzira na velika slova) menja cenu postojeće
  /// umesto da pravi duplikat. Vraća (dodato, izmenjeno).
  Future<({int added, int updated})> importAll(List<FixedRoute> routes);
}
