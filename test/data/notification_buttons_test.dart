import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/data/services/task_handler.dart';

List<String>? ids(Map<String, dynamic> event, {bool english = false}) =>
    rideNotificationButtons(event, english: english)?.map((b) => b.id).toList();

void main() {
  test('vožnja u toku: PAUZA i ZAVRŠI; pauza: NASTAVI i ZAVRŠI', () {
    expect(ids({'event': 'started'}), ['pause', 'stop']);
    expect(ids({'event': 'resumed'}), ['pause', 'stop']);
    expect(ids({'event': 'paused'}), ['resume', 'stop']);
  });

  test('oporavljena vožnja prati da li je bila pauzirana', () {
    expect(ids({'event': 'recovered', 'paused': false}), ['pause', 'stop']);
    expect(ids({'event': 'recovered', 'paused': true}), ['resume', 'stop']);
  });

  test('kraj vožnje sklanja dugmad; ostali događaji ih ne menjaju', () {
    expect(ids({'event': 'stopped'}), isEmpty);
    expect(ids({'event': 'update'}), isNull);
    expect(ids({'event': 'ready', 'active': true}), isNull);
    expect(ids({'event': 'error', 'cmd': 'stop'}), isNull);
  });

  test('tekst dugmadi prati jezik', () {
    final sr = rideNotificationButtons({'event': 'started'}, english: false)!;
    final en = rideNotificationButtons({'event': 'paused'}, english: true)!;
    expect(sr.map((b) => b.text), ['PAUZA', 'ZAVRŠI']);
    expect(en.map((b) => b.text), ['RESUME', 'END']);
  });
}
