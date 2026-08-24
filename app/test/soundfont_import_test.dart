import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/soundfont_manager.dart';
import 'package:rewamp/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un en-tête SF2 minimal: 'RIFF' <taille> 'sfbk'. C'est exactement ce que
/// l'import contrôle — le reste du fichier ne le regarde pas.
Uint8List _sf2(String tail) => Uint8List.fromList([
      ...'RIFF'.codeUnits,
      0, 0, 0, 0,
      ...'sfbk'.codeUnits,
      ...tail.codeUnits,
    ]);

void main() {
  late Directory tmp;
  late SoundfontManager mgr;

  setUp(() async {
    // delete() lit la sélection persistée (une soundfont supprimée ne doit pas
    // rester sélectionnée) — d'où les préférences en mémoire.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await UserSettings.init();
    tmp = Directory.systemTemp.createTempSync('rewamp_sf_');
    mgr = SoundfontManager.instance;
    mgr.init(tmp.path, null);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  File src(String name, Uint8List bytes) {
    final f = File('${tmp.path}/$name')..createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    return f;
  }

  test('un fichier qui n\'est pas une SF2 est REFUSÉ', () async {
    // Sans ce contrôle, FluidLite ne proteste pas: il rend un synthé MUET, et
    // le bug se présente plus tard comme « le MIDI ne marche plus ».
    final bad = src('notes.txt', Uint8List.fromList('hello world!!'.codeUnits));
    expect(() => mgr.importLocal(bad.path), throwsA(isA<FormatException>()));
    expect(mgr.localFonts(), isEmpty);
  });

  test('un fichier absent est refusé', () {
    expect(() => mgr.importLocal('${tmp.path}/nope.sf2'),
        throwsA(isA<FormatException>()));
  });

  test('une SF2 est COPIÉE, listée, et garde son nom d\'origine', () async {
    final f = src('Arachno SoundFont – v1.0.sf2', _sf2('data'));
    final slug = await mgr.importLocal(f.path);

    expect(SoundfontManager.isLocalSlug(slug), isTrue,
        reason: 'le préfixe sépare les importations des slugs du catalogue');
    // Copiée: le chemin d'origine est un fichier de bac à sable sur iOS.
    expect(File(mgr.pathFor(slug)).existsSync(), isTrue);
    expect(File(mgr.pathFor(slug)).readAsBytesSync(), f.readAsBytesSync());

    final listed = mgr.localFonts();
    expect(listed.length, 1);
    // Le NOM affiché survit à l'aplatissement du slug.
    expect(listed.single.name, 'Arachno SoundFont – v1.0');
    expect(listed.single.slug, slug);
    expect(listed.single.sizeBytes, greaterThan(0));
  });

  test('deux fichiers de même nom ne s\'écrasent pas', () async {
    final a = src('sub_a/Fonte.sf2', _sf2('aaaa'));
    final b = src('sub_b/Fonte.sf2', _sf2('bbbbbbbb'));
    final s1 = await mgr.importLocal(a.path);
    final s2 = await mgr.importLocal(b.path);
    expect(s1, isNot(s2));
    expect(mgr.localFonts().length, 2);
    // Chacune garde SES octets.
    expect(File(mgr.pathFor(s1)).lengthSync(), a.lengthSync());
    expect(File(mgr.pathFor(s2)).lengthSync(), b.lengthSync());
  });

  test('supprimer emporte le fichier ET son nom voisin', () async {
    final slug = await mgr.importLocal(src('X.sf2', _sf2('zz')).path);
    await mgr.delete(slug);
    expect(mgr.localFonts(), isEmpty);
    expect(File(mgr.pathFor(slug)).existsSync(), isFalse);
    // Le voisin de nom resté seul ferait réapparaître une entrée fantôme au
    // prochain import portant le même slug.
    expect(
        Directory(tmp.path)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.name'))
            .isEmpty,
        isTrue);
  });
}
