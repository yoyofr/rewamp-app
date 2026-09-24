import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/app_shell.dart' show preferredMidiPluginFor;

// Le réglage « Synthé MIDI » se traduit en une ÉPINGLE du registre natif —
// ou en son absence. Les deux moteurs .mid scorent 100 (aucun n'est
// exclusif, sinon l'épingle ne pourrait jamais gagner), FluidLite étant
// enregistré le premier; sans épingle il gagne l'égalité, et le MT-32 ne
// l'emporte que sur un fichier qui porte son sysex (104).
void main() {
  test('auto = aucune épingle, le classement natif décide', () {
    expect(preferredMidiPluginFor('auto'), isNull);
  });
  test('soundfont épingle FluidLite', () {
    expect(preferredMidiPluginFor('soundfont'), 'fluidlite');
  });
  test('mt32 épingle mt32emu', () {
    expect(preferredMidiPluginFor('mt32'), 'mt32');
  });
  test('une valeur inconnue vaut auto, jamais une épingle inventée', () {
    expect(preferredMidiPluginFor('adlmidi'), isNull);
    expect(preferredMidiPluginFor(''), isNull);
  });
}
