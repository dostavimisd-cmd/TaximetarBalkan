import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/models/app_settings.dart';
import 'package:taksimetar_balkan/presentation/providers/taximeter_provider.dart';
import 'package:taksimetar_balkan/presentation/services/ride_feedback.dart';

void main() {
  test('signal samo za potvrđene promene faze', () {
    expect(rideFeedbackFor(RidePhase.starting, RidePhase.running), RideFeedback.started);
    expect(rideFeedbackFor(RidePhase.running, RidePhase.paused), RideFeedback.paused);
    expect(rideFeedbackFor(RidePhase.paused, RidePhase.running), RideFeedback.resumed);
    expect(rideFeedbackFor(RidePhase.stopping, RidePhase.finished), RideFeedback.finished);
    expect(rideFeedbackFor(RidePhase.paused, RidePhase.finished), RideFeedback.finished);
  });

  test('bez signala: dodir koji još čeka servis, oporavak, ista faza', () {
    expect(rideFeedbackFor(RidePhase.idle, RidePhase.starting), isNull);
    expect(rideFeedbackFor(RidePhase.running, RidePhase.stopping), isNull);
    expect(rideFeedbackFor(RidePhase.idle, RidePhase.running), isNull); // oporavak
    expect(rideFeedbackFor(null, RidePhase.running), isNull);
    expect(rideFeedbackFor(RidePhase.running, RidePhase.running), isNull);
    expect(rideFeedbackFor(RidePhase.finished, RidePhase.finished), isNull);
    expect(rideFeedbackFor(RidePhase.starting, RidePhase.idle), isNull); // start nije uspeo
  });

  test('podešavanje: podrazumevano uključeno, čuva se', () {
    expect(AppSettings.fromMap(const {}).buttonFeedback, isTrue);
    final off = const AppSettings().copyWith(buttonFeedback: false);
    expect(AppSettings.fromMap(off.toMap()).buttonFeedback, isFalse);
  });

  test('automatska štampa: podrazumevano isključena, čuva se', () {
    expect(AppSettings.fromMap(const {}).autoPrint, isFalse);
    final on = const AppSettings().copyWith(autoPrint: true);
    expect(AppSettings.fromMap(on.toMap()).autoPrint, isTrue);
  });
}
