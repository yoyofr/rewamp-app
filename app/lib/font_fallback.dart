// Le repli de police pour le chinois, le japonais et le coréen — sous LINUX.
//
// ⚠️ Constaté le 2026-09-21: sous Linux, TOUT texte CJK s'affichait en
// RECTANGLES — les titres venus du serveur (`平田 祥一郎`), mais aussi
// l'interface elle-même dans les trois langues CJK de l'app (ja, zh, ko: trois
// sur dix-huit, inutilisables). Mesuré sur une capture de l'app lancée en
// japonais: seul le japonais DESSINÉ dans les pochettes apparaissait.
//
// Ni l'encodage (le serveur envoie de l'Unicode propre, sans aucun caractère de
// contrôle), ni l'absence de police: `fc-match "sans-serif:charset=5e73"` rend
// bien Noto Sans CJK JP sur la même machine. C'est le repli PAR CARACTÈRE du
// moteur Flutter sous Linux qui ne la trouve pas. Nommer les familles en
// `fontFamilyFallback` le contourne: Flutter les demande alors PAR NOM, ce que
// fontconfig résout sans détour.
//
// Seulement sous Linux: ailleurs le repli système fonctionne, et une liste de
// noms Linux n'y ajouterait que des recherches inutiles.
//
// ⚠️ L'ORDRE compte (unification Han): un même point de code — 直, 骨, 誤… —
// se dessine différemment selon la variante japonaise, chinoise ou coréenne.
// La variante de la langue de l'interface passe donc en tête; le japonais
// sinon, la langue la plus fréquente des tags de musique de jeu.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Les familles, par variante, sous les noms que les distributions installent:
/// Noto (Debian/Ubuntu `fonts-noto-cjk`, Fedora, Arch), son jumeau Adobe
/// « Source Han », puis des polices plus anciennes et répandues. Une famille
/// absente est simplement sautée par le moteur.
const _kByScript = <String, List<String>>{
  'ja': ['Noto Sans CJK JP', 'Source Han Sans JP', 'IPAGothic', 'IPAexGothic',
         'TakaoGothic', 'VL Gothic'],
  'zh': ['Noto Sans CJK SC', 'Source Han Sans SC', 'WenQuanYi Micro Hei',
         'WenQuanYi Zen Hei'],
  'zh_Hant': ['Noto Sans CJK TC', 'Source Han Sans TC'],
  'ko': ['Noto Sans CJK KR', 'Source Han Sans KR', 'NanumGothic',
         'UnDotum'],
};

/// Dernier recours: couvre les trois scripts, sans variante propre.
const _kLastResort = ['Droid Sans Fallback'];

/// La liste de repli pour une langue d'interface — `null` hors Linux.
///
/// [languageCode] et [scriptCode] sont ceux de la locale de l'appareil
/// (`zh` + `Hant` = chinois traditionnel).
List<String>? cjkFontFallback(String? languageCode, {String? scriptCode,
    TargetPlatform? platform}) {
  final linux = (platform ?? defaultTargetPlatform) == TargetPlatform.linux &&
      !kIsWeb;
  if (!linux) return null;
  var first = switch (languageCode) {
    'zh' => (scriptCode == 'Hant') ? 'zh_Hant' : 'zh',
    'ko' => 'ko',
    _ => 'ja',
  };
  final order = [first, ...['ja', 'zh', 'zh_Hant', 'ko'].where((k) => k != first)];
  return [for (final k in order) ..._kByScript[k]!, ..._kLastResort];
}

/// La locale de l'appareil, telle que le système la donne au démarrage.
List<String>? platformCjkFontFallback() {
  if (kIsWeb || !Platform.isLinux) return null;
  final l = PlatformDispatcher.instance.locale;
  return cjkFontFallback(l.languageCode, scriptCode: l.scriptCode);
}

/// Calculée une fois: la locale de l'appareil ne change pas en cours de route
/// d'une façon qui justifierait de la relire à chaque dessin.
final List<String>? _kPlatformFallback = platformCjkFontFallback();

/// Ajoute le repli CJK à un style qui n'en a PAS — et ne touche rien d'autre.
///
/// ⚠️ Le repli posé sur le thème ne vaut que pour les styles DÉRIVÉS du thème.
/// Il manque partout où un style brut est employé TEL QUEL: un `TextPainter`
/// (n'hérite jamais de rien — texte des visualiseurs, noms d'instruments), un
/// paramètre de widget Material qui REMPLACE le style hérité
/// (`NavigationRail.selectedLabelTextStyle`: seul libellé encore en rectangles
/// sur la capture du 2026-09-21), ou `ScrollingText(style:)`, qui remplace lui
/// aussi. Un `Text(style:)` ordinaire, lui, FUSIONNE avec le style hérité et
/// n'en a pas besoin.
TextStyle withCjkFallback(TextStyle style) {
  final fb = _kPlatformFallback;
  if (fb == null || style.fontFamilyFallback != null) return style;
  return style.copyWith(fontFamilyFallback: fb);
}
