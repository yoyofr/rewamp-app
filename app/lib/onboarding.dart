import 'package:flutter/material.dart';

import 'client_info.dart';
import 'l10n.dart';
import 'user_settings.dart';
import 'app_theme.dart';

/// First-run carousel: a welcome page, then a short tour of what the app does.
///
/// Shown ONCE, on the first launch. During the beta it came back at every
/// BUILD because its first page warned that local data could be wiped before
/// 1.0; that warning is gone with 1.0, and a tour replayed at each update is
/// noise — what changed is the release note's job. The persisted key is still
/// `onboarding.seen_build` (any non-empty value = seen), so a beta tester who
/// already went through it is not shown it again. Skipping counts as seen.
class Onboarding {
  Onboarding._();

  /// Shows the carousel unconditionally (About → Welcome tour).
  static Future<void> show(BuildContext context) => _push(context);

  /// Shows the carousel if it has never been acknowledged on this install.
  /// Safe to call unconditionally; returns immediately when already seen.
  static Future<void> maybeShow(BuildContext context) async {
    await ClientInfo.instance.ensureLoaded();
    final build = ClientInfo.instance.appBuild ?? '';
    final settings = UserSettings.instance;
    if (settings.onboardingSeenBuild.isNotEmpty) return;
    if (!context.mounted) return;
    await _push(context);
    settings.onboardingSeenBuild = build;
  }

  /// The carousel floats over a black87 scrim, so its palette is FORCED dark
  /// whatever the app theme is: under the light theme every label came out
  /// dark-on-black, i.e. unreadable. Same seed as the app theme (main.dart).
  static final ThemeData _overlayTheme = rewampThemeData(ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  ));

  static Future<void> _push(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black87,
          pageBuilder: (_, __, ___) =>
              Theme(data: _overlayTheme, child: const _OnboardingPages()),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
}

class _Page {
  final IconData icon;
  final String title;
  final String body;
  const _Page(this.icon, this.title, this.body);
}

class _OnboardingPages extends StatefulWidget {
  const _OnboardingPages();

  @override
  State<_OnboardingPages> createState() => _OnboardingPagesState();
}

class _OnboardingPagesState extends State<_OnboardingPages> {
  final _ctrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _next(int last) {
    if (_index >= last) {
      _close();
    } else {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final info = ClientInfo.instance;

    final pages = <_Page>[
      _Page(Icons.waving_hand_outlined, l10n.onboardingWelcomeTitle,
          l10n.onboardingWelcomeBody),
      _Page(Icons.travel_explore, l10n.onboardingExploreTitle,
          l10n.onboardingExploreBody),
      _Page(Icons.library_music_outlined, l10n.onboardingLibraryTitle,
          l10n.onboardingLibraryBody),
      _Page(Icons.graphic_eq, l10n.onboardingPlayerTitle,
          l10n.onboardingPlayerBody),
    ];
    final last = pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _close,
                child: Text(l10n.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final p = pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.icon, size: 72, color: cs.primary),
                        const SizedBox(height: 28),
                        Text(p.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        Text(p.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium),
                        // Version and build under the welcome page: what a user
                        // quotes in a bug report.
                        if (i == 0) ...[
                          const SizedBox(height: 20),
                          Text(
                            l10n.onboardingVersion(
                                info.appVersion ?? '?', info.appBuild ?? '?'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(32, 20, 32, 28),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _next(last),
                  child: Text(_index >= last
                      ? l10n.onboardingStart
                      : l10n.onboardingNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
