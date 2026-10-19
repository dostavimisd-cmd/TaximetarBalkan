import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/announcement.dart';

void main() {
  test('srpski: dinar / dinara', () {
    expect(Announcement.rideFinished(1), 'Ukupno 1 dinar.');
    expect(Announcement.rideFinished(21), 'Ukupno 21 dinar.');
    expect(Announcement.rideFinished(11), 'Ukupno 11 dinara.');
    expect(Announcement.rideFinished(111), 'Ukupno 111 dinara.');
    expect(Announcement.rideFinished(1250), 'Ukupno 1250 dinara.');
    expect(Announcement.rideFinished(1252), 'Ukupno 1252 dinara.');
  });

  test('fiksna relacija i engleski', () {
    expect(Announcement.rideFinished(2500, fixedRouteName: 'Aerodrom'),
        'Fiksna cena, Aerodrom: 2500 dinara.');
    expect(Announcement.rideFinished(300, language: 'en'), 'Total: 300 dinars.');
  });
}
