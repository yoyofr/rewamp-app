// Banques FM importées (WOPL / WOPN): l'en-tête décide du format, jamais
// l'extension; un homonyme ne remplace pas une banque déjà là; supprimer la
// banque choisie rend la main à la banque embarquée.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/fm_bank_manager.dart';
import 'package:rewamp/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> _head(String magic) => [...magic.codeUnits, 0, 3, 0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('l\'en-tête nomme le format', () {
    expect(fmBankKindOfHeader(_head('WOPL3-BANK')), FmBankKind.wopl);
    expect(fmBankKindOfHeader(_head('WOPN2-BANK')), FmBankKind.wopn);
    expect(fmBankKindOfHeader(_head('WOPN2-B2NK')), FmBankKind.wopn);
    expect(fmBankKindOfHeader('RIFF....sfbk'.codeUnits), isNull);
    expect(fmBankKindOfHeader('WOPL3-BANKX'.codeUnits), isNull); // pas de \0
    expect(fmBankKindOfHeader(const [1, 2]), isNull);
  });

  test('le filtre: chaque mot, sans casse, dans n\'importe quel ordre', () {
    expect(fmBankNameMatches('DMXOPL3 by sneakernets (GS)', ''), isTrue);
    expect(fmBankNameMatches('DMXOPL3 by sneakernets (GS)', 'gs dmx'), isTrue);
    expect(fmBankNameMatches('DMXOPL3 by sneakernets (GS)', 'fatman'), isFalse);
  });

  test('un nom de banque se reconnaît à son extension', () {
    expect(isFmBankFileName('/a/b/Doom.WOPL'), isTrue);
    expect(isFmBankFileName('x.wopn'), isTrue);
    expect(isFmBankFileName('song.mid'), isFalse);
    expect(isFmBankFileName('wopl'), isFalse);
  });

  group('import / suppression', () {
    late Directory tmp;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await UserSettings.init();
      tmp = await Directory.systemTemp.createTemp('fm_banks_test');
      FmBankManager.instance.initForTest(p.join(tmp.path, 'fm_banks'));
    });
    tearDown(() => tmp.delete(recursive: true));

    Future<String> bank(String name, String magic) async {
      final f = File(p.join(tmp.path, 'src', name));
      await f.parent.create(recursive: true);
      await f.writeAsBytes([..._head(magic), 1, 2, 3, 4]);
      return f.path;
    }

    test('le format vient du CONTENU: un .wopl qui est un WOPN va aux WOPN',
        () async {
      final (kind, b) = await FmBankManager.instance
          .import(await bank('mislabelled.wopl', 'WOPN2-B2NK'));
      expect(kind, FmBankKind.wopn);
      expect(b.fileName, 'mislabelled.wopn');
      expect(FmBankManager.instance.userBanks(FmBankKind.wopn).single.name,
          'mislabelled');
      expect(FmBankManager.instance.userBanks(FmBankKind.wopl), isEmpty);
    });

    test('un fichier qui n\'est pas une banque est refusé', () async {
      final f = File(p.join(tmp.path, 'junk.wopl'));
      await f.writeAsString('junk');
      expect(FmBankManager.instance.import(f.path), throwsFormatException);
    });

    test('un homonyme ne remplace pas la banque déjà là', () async {
      final a = await bank('Doom.wopl', 'WOPL3-BANK');
      await FmBankManager.instance.import(a);
      final (_, second) = await FmBankManager.instance.import(a);
      expect(second.fileName, 'Doom (2).wopl');
      expect(FmBankManager.instance.userBanks(FmBankKind.wopl).length, 2);
    });

    test('supprimer la banque choisie rend la main à l\'embarquée', () async {
      final (kind, b) = await FmBankManager.instance
          .import(await bank('Doom.wopl', 'WOPL3-BANK'));
      FmBankManager.instance.select(kind, b.fileName);
      expect(FmBankManager.instance.selectedPath(kind), isNotNull);
      await FmBankManager.instance.delete(kind, b.fileName);
      expect(UserSettings.instance.adlBankFile, isNull);
      expect(FmBankManager.instance.selectedPath(kind), isNull);
    });

    test('un fichier choisi puis disparu ne désigne plus rien', () async {
      final (kind, b) = await FmBankManager.instance
          .import(await bank('Gone.wopn', 'WOPN2-BANK'));
      FmBankManager.instance.select(kind, b.fileName);
      await File(FmBankManager.instance.pathFor(kind, b.fileName)).delete();
      expect(FmBankManager.instance.selectedPath(kind), isNull);
    });
  });
}
