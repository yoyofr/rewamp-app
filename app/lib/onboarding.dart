import 'package:flutter/material.dart';

import 'client_info.dart';
import 'l10n.dart';
import 'user_settings.dart';

/// First-run carousel: the beta warning, then a short tour of what the app does.
///
/// Shown once per BUILD, not once ever: this is a beta, the data-reset warning
/// stays relevant at every update, and a returning tester gets a two-second
/// reminder of what changed rather than nothing at all. Skipping counts as
/// seen — nobody is made to read it twice.
class Onboarding {
  Onboarding._();

  /// Shows the carousel unconditionally (About → Welcome tour).
  static Future<void> show(BuildContext context) => _push(context);

  /// Shows the carousel if this build has not been acknowledged yet.
  /// Safe to call unconditionally; returns immediately when already seen.
  static Future<void> maybeShow(BuildContext context) async {
    await ClientInfo.instance.ensureLoaded();
    final build = ClientInfo.instance.appBuild ?? '';
    final settings = UserSettings.instance;
    if (settings.onboardingSeenBuild == build) return;
    if (!context.mounted) return;
    await _push(context);
    settings.onboardingSeenBuild = build;
  }

  /// The carousel floats over a black87 scrim, so its palette is FORCED dark
  /// whatever the app theme is: under the light theme every label came out
  /// dark-on-black, i.e. unreadable. Same seed as the app theme (main.dart).
  static final ThemeData _overlayTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  );

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
      _Page(Icons.science_outlined, l10n.onboardingBetaTitle,
          l10n.onboardingBetaBody),
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
              alignment: Alignment.centerRight,
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
                        // The build is only meaningful next to the beta warning,
                        // and it is what a tester quotes in a bug report.
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
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 28),
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
