import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/heatmap.dart';

void main() {
  // utorak 5.11.2026. (lokalno)
  final tue9 = DateTime(2026, 11, 3, 9);
  final tue20 = DateTime(2026, 11, 3, 20);
  final sat9 = DateTime(2026, 11, 7, 9);

  test('bliski početci su jedna zona, daleki posebna; najjača prva', () {
    final cells = Heatmap.cells([
      RideStart(44.6640, 20.9270, tue9),
      RideStart(44.6641, 20.9271, tue9),
      RideStart(44.6642, 20.9272, sat9),
      RideStart(44.8125, 20.4612, tue20), // Beograd
    ]);
    expect(cells.map((c) => c.count), [3, 1]);
    expect(cells.first.lat, closeTo(44.6641, 0.001));
  });

  test('filter po danu i delu dana', () {
    final starts = [
      RideStart(44.6640, 20.9270, tue9),
      RideStart(44.6640, 20.9270, tue20),
      RideStart(44.6640, 20.9270, sat9),
    ];
    expect(Heatmap.cells(starts, weekdays: {DateTime.tuesday}).single.count, 2);
    expect(Heatmap.cells(starts, part: DayPart.morning).single.count, 2);
    expect(Heatmap.cells(starts, weekdays: {DateTime.saturday}, part: DayPart.evening), isEmpty);
    expect(DayPart.night.contains(3), isTrue);
    expect(DayPart.evening.contains(24), isFalse);
  });
}
