import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/user_settings.dart';

/// Déclic de début de piste des rips CD. Le natif vit dans
/// `src/rewamp_declick.c`, posé par le DATASOURCE (un `.ape` est joué par MAC,
/// un `.ogg` par vgmstream — la première version, dans le seul greffon
/// vgmstream, laissait claquer World Heroes Perfect `_02.ape`), et se vérifie
/// par `scripts/verify_declick.sh`. Ici on épingle la seule chose que le Dart
/// peut casser en silence: l'inscription du réglage aux DEUX tables — un
/// réglage neuf s'inscrit à DEUX endroits, et l'oubli est SILENCIEUX.
void main() {
  test('le réglage a son bouton de remise à zéro', () {
    expect(UserSettings.kEnginePrefKeys.containsKey('cdRipDeclick'), isTrue,
        reason: 'sans cette entrée, `_ResetDot` sort sur `prefKey == null` '
            'sans rien dessiner');
  });

  test('le réglage appartient à la section Lecture', () {
    final key = UserSettings.kEnginePrefKeys['cdRipDeclick'];
    expect(key, isNotNull);
    expect(UserSettings.kSectionKeys['playback'], contains(key));
  });
}
