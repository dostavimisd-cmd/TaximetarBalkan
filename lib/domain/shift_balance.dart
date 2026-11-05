import 'models/ride_record.dart';
import 'models/shift_expense.dart';

/// Zarada smene, troškovi i koliko ostaje za pazar (sve celi dinari).
class ShiftBalance {
  final int earnings;
  final int expenses;

  const ShiftBalance({required this.earnings, required this.expenses});

  /// Ostaje = zarada − troškovi (može biti i manje od nule).
  int get remaining => earnings - expenses;

  factory ShiftBalance.of(
    Iterable<RideRecord> rides,
    Iterable<ShiftExpense> expenses,
  ) =>
      ShiftBalance(
        earnings: rides.fold(0, (s, r) => s + r.totalPrice),
        expenses: expenses.fold(0, (s, e) => s + e.amount),
      );

  /// Napredak ka cilju 0.0–1.0; null kad cilj nije postavljen.
  static double? goalProgress(int earned, int goal) {
    if (goal <= 0) return null;
    final p = earned / goal;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }
}
