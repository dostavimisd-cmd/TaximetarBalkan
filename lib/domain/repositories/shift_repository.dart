import '../models/shift.dart';
import '../models/shift_expense.dart';

abstract class ShiftRepository {
  /// Smene, najnovija prva.
  Future<List<Shift>> getAll();

  /// Otvorena smena ili null.
  Future<Shift?> current();

  /// Počinje smenu; ako je neka već otvorena, vraća nju.
  Future<Shift> start(DateTime nowUtc);

  /// Završava otvorenu smenu (ako postoji).
  Future<void> end(DateTime nowUtc);

  /// Troškovi smene po redu unosa.
  Future<List<ShiftExpense>> getExpenses(int shiftId);

  /// Upisuje trošak (baca [ArgumentError] ako nije ispravan); vraća id.
  Future<int> addExpense(ShiftExpense expense, DateTime nowUtc);

  Future<void> deleteExpense(int id);
}
