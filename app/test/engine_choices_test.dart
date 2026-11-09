// « Lire avec… »: ordre de résolution (ponctuel → fichier → album), portée
// des choix, et un choix ponctuel qui ne survit pas au morceau suivant.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/engine_choices.dart';
import 'package:rewamp/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a1 = '/m/Doom 2/04 - Stalks.mid';
  const a2 = '/m/Doom 2/05 - Sinister.mid';
  const b1 = '/m/Other/x.mid';
  final ch = EngineChoices.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSettings.init();
    ch.forgetAll();
  });

  test('rien de choisi: le classement du registre', () {
    expect(ch.choiceFor(a1), isNull);
  });

  test('un choix d\'album couvre tout le dossier, pas un autre', () {
    ch.choose(a1, 'adlmidi', EngineChoiceScope.album);
    expect(ch.choiceFor(a2), ('adlmidi', EngineChoiceScope.album));
    expect(ch.choiceFor(b1), isNull);
  });

  test('le fichier l\'emporte sur l\'album, le ponctuel sur les deux', () {
    ch.choose(a1, 'adlmidi', EngineChoiceScope.album);
    ch.choose(a2, 'opnmidi', EngineChoiceScope.file);
    expect(ch.choiceFor(a2), ('opnmidi', EngineChoiceScope.file));
    ch.choose(a2, 'fluidlite', EngineChoiceScope.once);
    expect(ch.choiceFor(a2), ('fluidlite', EngineChoiceScope.once));
    expect(ch.choiceFor(a1), ('adlmidi', EngineChoiceScope.album));
  });

  test('choisir pour l\'album efface le choix propre au fichier', () {
    ch.choose(a1, 'opnmidi', EngineChoiceScope.file);
    ch.choose(a1, 'adlmidi', EngineChoiceScope.album);
    expect(ch.choiceFor(a1), ('adlmidi', EngineChoiceScope.album));
  });

  test('« Automatique » pour un fichier passe DEVANT le choix de l\'album', () {
    ch.choose(a1, 'adlmidi', EngineChoiceScope.album);
    ch.choose(a1, 'opnmidi', EngineChoiceScope.file);
    ch.choose(a1, null, EngineChoiceScope.file);
    expect(ch.choiceFor(a1), isNull);                       // le registre décide
    expect(ch.scopeOf(a1), EngineChoiceScope.file);         // et c'est un choix
    expect(ch.choiceFor(a2), ('adlmidi', EngineChoiceScope.album));
  });

  test('« Automatique » pour un fichier sans album: l\'entrée disparaît', () {
    ch.choose(a1, 'opnmidi', EngineChoiceScope.file);
    ch.choose(a1, null, EngineChoiceScope.file);
    expect(ch.scopeOf(a1), isNull);
    expect(ch.rememberedCount, 0);
  });

  test('« Automatique » pour l\'album efface AUSSI les choix de ses fichiers', () {
    ch.choose(a1, 'opnmidi', EngineChoiceScope.file);
    ch.choose(a2, 'mt32', EngineChoiceScope.file);
    ch.choose(b1, 'mt32', EngineChoiceScope.file);   // autre dossier: intact
    ch.choose(a1, 'adlmidi', EngineChoiceScope.album);
    ch.choose(a1, null, EngineChoiceScope.album);
    expect(ch.scopeOf(a1), isNull);
    expect(ch.scopeOf(a2), isNull);
    expect(ch.choiceFor(b1), ('mt32', EngineChoiceScope.file));
    expect(ch.rememberedCount, 1);
  });

  test('un « Automatique » ponctuel passe devant ce qui est retenu', () {
    ch.choose(a1, 'opnmidi', EngineChoiceScope.file);
    ch.choose(a1, null, EngineChoiceScope.once);
    expect(ch.choiceFor(a1), isNull);
    expect(ch.scopeOf(a1), EngineChoiceScope.once);
  });

  test('tout oublier (Réglages → Données)', () {
    ch.choose(a1, 'opnmidi', EngineChoiceScope.file);
    ch.choose(b1, 'mt32', EngineChoiceScope.album);
    expect(ch.rememberedCount, 2);
    ch.forgetAll();
    expect(ch.rememberedCount, 0);
    expect(ch.choiceFor(a1), isNull);
  });

  test('un choix retenu survit à un redémarrage (préférence)', () async {
    ch.choose(a1, 'mt32', EngineChoiceScope.file);
    final raw = UserSettings.instance.engineChoicesJson;
    SharedPreferences.setMockInitialValues({'playback.engine_choices': raw!});
    await UserSettings.init();
    expect(ch.choiceFor(a1), ('mt32', EngineChoiceScope.file));
  });

  test('libellés: noms propres, inconnu tel quel', () {
    expect(enginePluginLabel('adlmidi'), 'libADLMIDI (OPL3)');
    expect(enginePluginLabel('zzz'), 'zzz');
  });

  group('banque FM', () {
    const imp = FmBankImported('Doom.wopl');

    test('même résolution que le moteur, espace de noms à part', () {
      ch.chooseBank('adlmidi', a1, const FmBankBuiltin(12), EngineChoiceScope.album);
      ch.chooseBank('adlmidi', a2, imp, EngineChoiceScope.file);
      expect(ch.bankChoiceFor('adlmidi', a1), (const FmBankBuiltin(12), EngineChoiceScope.album));
      expect(ch.bankChoiceFor('adlmidi', a2), (imp, EngineChoiceScope.file));
      expect(ch.bankChoiceFor('opnmidi', a1), isNull);
      expect(ch.choiceFor(a1), isNull);   // le moteur n'est pas touché
    });

    test('choisir la banque de l\'album ne touche pas au moteur du fichier', () {
      ch.choose(a1, 'opnmidi', EngineChoiceScope.file);
      ch.chooseBank('adlmidi', a1, const FmBankBuiltin(3), EngineChoiceScope.album);
      expect(ch.choiceFor(a1), ('opnmidi', EngineChoiceScope.file));
    });

    test('ponctuel par espace de noms, expiré au fichier suivant', () {
      ch.choose(a1, 'adlmidi', EngineChoiceScope.once);
      ch.chooseBank('adlmidi', a1, const FmBankBuiltin(5), EngineChoiceScope.once);
      expect(ch.bankChoiceFor('adlmidi', a1)?.$2, EngineChoiceScope.once);
      expect(ch.choiceFor(a1)?.$2, EngineChoiceScope.once);
    });

    test('usage d\'une banque importée, puis oubli à sa suppression', () {
      ch.chooseBank('adlmidi', a1, imp, EngineChoiceScope.file);
      ch.chooseBank('adlmidi', b1, imp, EngineChoiceScope.album);
      ch.chooseBank('opnmidi', a2, const FmBankImported('Doom.wopl'), EngineChoiceScope.file);
      expect(ch.importedBankUsage('adlmidi', 'Doom.wopl'), (1, 1));
      ch.forgetImportedBank('adlmidi', 'Doom.wopl');
      expect(ch.importedBankUsage('adlmidi', 'Doom.wopl'), (0, 0));
      expect(ch.bankChoiceFor('adlmidi', a1), isNull);
      expect(ch.bankChoiceFor('opnmidi', a2)?.$1, imp);   // l'autre moteur garde la sienne
    });

    test('forme stockée relue', () {
      expect(FmBankRef.parse('#7'), const FmBankBuiltin(7));
      expect(FmBankRef.parse('u:a b.wopn'), const FmBankImported('a b.wopn'));
      expect(FmBankRef.parse('x'), isNull);
      expect(FmBankRef.parse('#-1'), isNull);
    });
  });

  group('options (SoundFont, modèle MT-32)', () {
    test('même résolution, espace par greffon', () {
      ch.chooseOption('fluidlite', a1, 'local-arachno', EngineChoiceScope.album);
      ch.chooseOption('mt32', a2, '2', EngineChoiceScope.file);
      expect(ch.optionChoiceFor('fluidlite', a2), ('local-arachno', EngineChoiceScope.album));
      expect(ch.optionChoiceFor('mt32', a2), ('2', EngineChoiceScope.file));
      expect(ch.optionChoiceFor('mt32', a1), isNull);
      expect(ch.bankChoiceFor('adlmidi', a1), isNull);
    });

    test('usage puis oubli d\'une SoundFont supprimée', () {
      ch.chooseOption('fluidlite', a1, 'gm', EngineChoiceScope.file);
      ch.chooseOption('fluidlite', b1, 'gm', EngineChoiceScope.album);
      ch.chooseOption('fluidlite', a2, 'other', EngineChoiceScope.file);
      expect(ch.optionUsage('fluidlite', 'gm'), (1, 1));
      ch.forgetOption('fluidlite', 'gm');
      expect(ch.optionUsage('fluidlite', 'gm'), (0, 0));
      expect(ch.optionChoiceFor('fluidlite', a2)?.$1, 'other');
    });
  });
}
