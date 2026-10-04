import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/picker_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le sélecteur s'ouvrait toujours sur le défaut du système (le home sur
/// macOS). Il reprend désormais le dernier dossier de son USAGE, et retombe
/// sur le défaut quand ce dossier n'existe plus.
void main() {
  final desktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  test('un dossier existant est rendu; disparu ou vide = null (défaut du système)', () {
    final d = Directory.systemTemp.createTempSync('picker_');
    expect(PickerMemory.usableDir(d.path), d.path);
    d.deleteSync();
    expect(PickerMemory.usableDir(d.path), isNull);
    expect(PickerMemory.usableDir(null), isNull);
    expect(PickerMemory.usableDir(''), isNull);
  });

  // Sous les DEUX styles de chemin, sur n'importe quelle machine.
  test('un DOSSIER choisi se retient par son parent (POSIX)', () {
    String? f(String? d) => PickerMemory.folderStartDir(d, ctx: p.posix);
    expect(f('/Users/x/Music/sid'), '/Users/x/Music');
    expect(f('/Users/x/Music/sid/'), '/Users/x/Music');
    expect(f('/'), '/');
    expect(f(null), isNull);
  });

  test('un DOSSIER choisi se retient par son parent (Windows)', () {
    String? f(String? d) => PickerMemory.folderStartDir(d, ctx: p.windows);
    expect(f(r'C:\Users\x\Music\sid'), r'C:\Users\x\Music');
    expect(f(r'C:\Users\x\Music\sid\'), r'C:\Users\x\Music');
    expect(f(r'C:\'), r'C:\');
  });

  test('aller-retour par usage, puis repli quand le dossier disparaît', () async {
    SharedPreferences.setMockInitialValues({});
    final d = Directory.systemTemp.createTempSync('picker_');
    final f = File(p.join(d.path, 'theme.mid'))..writeAsStringSync('x');
    await PickerMemory.rememberFile(PickerSlot.music, f.path);
    expect(await PickerMemory.startDir(PickerSlot.music), d.path);
    expect(await PickerMemory.startDir(PickerSlot.presets), isNull);
    await PickerMemory.rememberFolder(PickerSlot.presets, p.join(d.path, 'packs'));
    expect(await PickerMemory.startDir(PickerSlot.presets), d.path);
    d.deleteSync(recursive: true);
    expect(await PickerMemory.startDir(PickerSlot.music), isNull);
  }, skip: !desktop);
}
