import 'package:flutter/services.dart';
import '../providers/taximeter_provider.dart';

/// Šta se desilo sa vožnjom, za kratak signal vozaču (vibracija i zvuk).
enum RideFeedback { started, paused, resumed, finished }

/// Signal za promenu faze vožnje; null kad nema šta da se javi.
/// Javlja samo potvrđene promene (servis je odgovorio), ne sam dodir dugmeta,
/// pa radi isto i kad komanda dođe iz obaveštenja. Oporavak vožnje pri
/// otvaranju aplikacije (idle → running) se ne javlja.
RideFeedback? rideFeedbackFor(RidePhase? prev, RidePhase next) {
  if (prev == next) return null;
  if (next == RidePhase.finished) return RideFeedback.finished;
  if (prev == RidePhase.starting && next == RidePhase.running) {
    return RideFeedback.started;
  }
  if (prev == RidePhase.running && next == RidePhase.paused) {
    return RideFeedback.paused;
  }
  if (prev == RidePhase.paused && next == RidePhase.running) {
    return RideFeedback.resumed;
  }
  return null;
}

/// Vibracija i sistemski zvuk dodira. Zvuk se čuje samo ako su zvuci dodira
/// uključeni u podešavanjima telefona; vibracija prati sistemsku vibraciju.
Future<void> playRideFeedback(RideFeedback feedback) async {
  switch (feedback) {
    case RideFeedback.started:
    case RideFeedback.finished:
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.heavyImpact();
    case RideFeedback.paused:
    case RideFeedback.resumed:
      await HapticFeedback.mediumImpact();
  }
  await SystemSound.play(SystemSoundType.click);
}
