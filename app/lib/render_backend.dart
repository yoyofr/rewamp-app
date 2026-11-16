// macOS: le moteur de rendu de Flutter — Impeller ou Skia.
//
// Pourquoi un réglage: Impeller est le rendu par défaut de Flutter sur macOS
// depuis la 3.47, et sur des Mac INTEL (MacBook Pro 16" 2019, Intel UHD 630 et
// Radeon Pro, macOS 26) il corrompt le TEXTE — glyphes mélangés, morceaux
// d'autres lettres — dès le lancement, quel que soit le GPU actif (rapporté
// par un utilisateur le 2026-11-11; images et icônes intactes, donc l'atlas de
// glyphes). Skia n'a pas ce défaut. D'où le défaut AUTOMATIQUE: Impeller sur
// Apple Silicon (l'effet verre complet en dépend), Skia sur Intel.
//
// ⚠️ Le moteur choisit son rendu AVANT que Dart n'existe, et en release il ne
// lit QUE `FLTEnableImpeller` dans l'Info.plist (`-[FlutterDartProject
// enableImpeller]`: `[[NSBundle mainBundle] objectForInfoDictionaryKey:]`;
// `FLUTTER_ENGINE_SWITCHES` n'est lu qu'en debug/profile). Le runner
// (AppDelegate.swift, `RendererChoice`) intercepte donc cette lecture-là, et
// Dart lui CONFIE le choix (`rewamp/cli` `setRenderer`, rangé en
// UserDefaults) — même mécanique que launch_window.dart. Le changement vaut
// au PROCHAIN lancement.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'user_settings.dart';

enum RenderBackend {
  auto,
  impeller,
  skia;

  static RenderBackend fromName(String? s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return RenderBackend.auto;
  }

  /// Les noms des deux moteurs sont des noms PROPRES (non traduits).
  String label(AppLocalizations l10n) => switch (this) {
        RenderBackend.auto     => l10n.settingsRenderBackendAuto,
        RenderBackend.impeller => 'Impeller',
        RenderBackend.skia     => 'Skia',
      };

  String hint(AppLocalizations l10n) => switch (this) {
        RenderBackend.auto     => l10n.settingsRenderBackendAutoHint,
        RenderBackend.impeller => l10n.settingsRenderBackendImpellerHint,
        RenderBackend.skia     => l10n.settingsRenderBackendSkiaHint,
      };
}

/// Ce que le runner a FAIT à ce lancement-ci: Impeller ou pas, et la machine.
class RenderBackendInfo {
  final bool impeller;
  final bool appleSilicon;
  const RenderBackendInfo({required this.impeller, required this.appleSilicon});
}

/// Le réglage n'existe que sur macOS (Windows et Linux ont leur propre
/// histoire de rendu, non touchée ici).
bool get renderBackendSupported => !kIsWeb && Platform.isMacOS;

const _cli = MethodChannel('rewamp/cli');
String? _sent;
RenderBackendInfo? _info;

/// L'état de CE lancement, demandé une fois au runner.
Future<RenderBackendInfo?> renderBackendInfo() async {
  if (!renderBackendSupported) return null;
  if (_info != null) return _info;
  try {
    final m = await _cli.invokeMapMethod<String, dynamic>('rendererInfo');
    if (m == null) return null;
    return _info = RenderBackendInfo(
      impeller: m['impeller'] == true,
      appleSilicon: m['appleSilicon'] == true,
    );
  } catch (e) {
    debugPrint('[render-backend] $e');
    return null;
  }
}

/// Recopie le réglage chez le runner — seulement quand il CHANGE. À appeler au
/// démarrage et à chaque changement des réglages (remise à zéro comprise, qui
/// EFFACE la clé sans passer par le setter).
Future<void> syncRenderBackend() async {
  if (!renderBackendSupported) return;
  final name = UserSettings.instance.renderBackend.name;
  if (_sent == name) return;
  try {
    await _cli.invokeMethod<void>('setRenderer', name);
    _sent = name;
  } catch (e) {
    debugPrint('[render-backend] $e');
  }
}

/// Le choix donne-t-il Impeller sur cette machine? (pour dire « au prochain
/// lancement » quand il diffère de ce qui tourne.)
bool renderBackendWantsImpeller(RenderBackend b, RenderBackendInfo info) =>
    switch (b) {
      RenderBackend.auto     => info.appleSilicon,
      RenderBackend.impeller => true,
      RenderBackend.skia     => false,
    };
