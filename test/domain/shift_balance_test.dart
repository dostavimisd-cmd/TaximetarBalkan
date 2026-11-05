import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/ride_record.dart';
import 'package:taksimetar_balkan/domain/models/shift_expense.dart';
import 'package:taksimetar_balkan/domain/shift_balance.dart';

RideRecord ride(int total) => RideRecord(
      id: total,
      startTime: DateTime.utc(2026, 11, 5, 8),
      endTime: DateTime.utc(2026, 11, 5, 8, 10),
      distanceMeters: 1000,
      waitingSeconds: 0,
      startPrice: total,
      kmPrice: 0,
      waitingPrice: 0,
      minPriceAdjustment: 0,
      totalPrice: total,
      status: 'completed',
    );

void main() {
  test('zarada, troškovi i koliko ostaje', () {
    final b = ShiftBalance.of(
      [ride(1200), ride(800)],
      const [
        ShiftExpense(shiftId: 1, name: 'Gorivo', amount: 1500),
        ShiftExpense(shiftId: 1, name: 'Pranje', amount: 300),
      ],
    );
    expect(b.earnings, 2000);
    expect(b.expenses, 1800);
    expect(b.remaining, 200);
    expect(ShiftBalance.of(const [], const [ShiftExpense(shiftId: 1, name: 'X', amount: 50)]).remaining, -50);
  });

  test('napredak ka cilju: 0–1, bez cilja null', () {
    expect(ShiftBalance.goalProgress(3000, 6000), 0.5);
    expect(ShiftBalance.goalProgress(9000, 6000), 1.0);
    expect(ShiftBalance.goalProgress(0, 6000), 0.0);
    expect(ShiftBalance.goalProgress(100, 0), isNull);
  });
}
