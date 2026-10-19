import '../models/fixed_route.dart';

abstract class FixedRouteRepository {
  Future<List<FixedRoute>> getAll();
  Future<int> save(FixedRoute route);
  Future<void> delete(int id);
}
