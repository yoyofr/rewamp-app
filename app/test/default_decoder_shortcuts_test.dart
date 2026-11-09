// Raccourci « lecteur par défaut » des pages moteur: un raccourci que l'on
// touche rend son moteur COURANT, et un format n'a jamais deux moteurs
// courants à la fois (MIDI « auto » = FluidLite, voir la table).
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/default_decoder_shortcuts.dart';
import 'package:rewamp/l10n.dart';
import 'package:rewamp/l10n/app_localizations_en.dart';
import 'package:rewamp/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final AppLocalizations l10n = AppLocalizationsEn();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSettings.init();
  });

  test('choisir rend courant, et un seul moteur par format', () {
    final s = UserSettings.instance;
    for (final entry in kDefaultDecoderShortcuts.entries) {
      for (final d in entry.value) {
        d.select(s);
        expect(d.isCurrent(s), isTrue, reason: '${entry.key} ${d.format(l10n)}');
        final rivals = [
          for (final e in kDefaultDecoderShortcuts.entries)
            for (final o in e.value)
              if (o.format(l10n) == d.format(l10n) && o.isCurrent(s)) e.key,
        ];
        expect(rivals, [entry.key], reason: d.format(l10n));
      }
    }
  });

  test('MIDI « auto » (défaut) est FluidLite', () {
    final fl = kDefaultDecoderShortcuts['fluidlite']!.single;
    expect(UserSettings.instance.midiSynth, 'auto');
    expect(fl.isCurrent(UserSettings.instance), isTrue);
  });
}
