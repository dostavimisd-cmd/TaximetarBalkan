import 'package:flutter_test/flutter_test.dart';
import 'package:taksimetar_balkan/domain/voice_command.dart';

void main() {
  test('srpski, ćirilica i engleski', () {
    expect(VoiceCommands.parse('Start'), VoiceCommand.start);
    expect(VoiceCommands.parse('kreni'), VoiceCommand.start);
    expect(VoiceCommands.parse('Pauza'), VoiceCommand.pause);
    expect(VoiceCommands.parse('nastavi vožnju'), VoiceCommand.resume);
    expect(VoiceCommands.parse('Završi'), VoiceCommand.stop);
    expect(VoiceCommands.parse('крај'), VoiceCommand.stop);
    expect(VoiceCommands.parse('end ride'), VoiceCommand.stop);
  });

  test('nejasno ili ništa → null (ne pogađa)', () {
    expect(VoiceCommands.parse('start pa kraj'), isNull);
    expect(VoiceCommands.parse('dobar dan'), isNull);
    expect(VoiceCommands.parse(''), isNull);
    expect(VoiceCommands.parse('startovati'), isNull); // samo cela reč
  });
}
