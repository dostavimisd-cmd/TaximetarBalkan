import '../models/shift.dart';

abstract class ShiftRepository {
  /// Smene, najnovija prva.
  Future<List<Shift>> getAll();

  /// Otvorena smena ili null.
  Future<Shift?> current();

  /// Počinje smenu; ako je neka već otvorena, vraća nju.
  Future<Shift> start(DateTime nowUtc);

  /// Završava otvorenu smenu (ako postoji).
  Future<void> end(DateTime nowUtc);
}
