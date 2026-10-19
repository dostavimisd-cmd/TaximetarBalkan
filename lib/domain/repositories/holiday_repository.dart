import '../models/holiday.dart';

abstract class HolidayRepository {
  Future<List<Holiday>> getAll();
  Future<int> save(Holiday holiday);
  Future<void> delete(int id);
}
