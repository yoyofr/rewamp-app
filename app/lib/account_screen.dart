import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'app_snack.dart';
import 'display_name_dialog.dart';
import 'l10n.dart';
import 'local_db.dart';
import 'rewamp_db.dart';
import 'sync_service.dart';
import 'user_settings.dart';
import 'shell_insets.dart';

/// Account screen — the visible entry point of the identity model.
///
/// There is exactly one credential: the signed token in
/// [UserSettings.authToken] (migrations 188/189). It is issued on first launch
/// and already carries the server-side library and listening history; the UUID
/// beside it is a display value that proves nothing. Attaching an email does
/// NOT create a second identity: it only makes the account recoverable on
/// another install, which is why the whole screen is phrased around "saving"
/// the account rather than "signing up".
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  RewampAccount? _account;
  bool _loading = true;
  bool _failed = false;
  /// Library changes still queued locally (offline gestures) — the account
  /// screen is where "is everything saved?" gets answered.
  int _pending = 0;

  Future<void> _refreshPending() async {
    final n = await LocalDb.instance.pendingSyncCount();
    if (mounted) setState(() => _pending = n);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!UserSettings.instance.hasAuthToken) {
      // No credential yet (first launch offline, a failed registration, or an
      // install predating the token) — try once. The uuid alone authenticates
      // nothing since migration 188, so this checks the token, not the id.
      final fresh = await RewampDb.registerUser();
      if (fresh != null && fresh.isNotEmpty) {
        await UserSettings.instance.setUserId(fresh);
      }
    }
    if (!UserSettings.instance.hasAuthToken) {
      if (mounted) setState(() { _loading = false; _failed = true; });
      return;
    }
    await _refreshPending();
    final acc = await RewampDb.getAccount();
    // Gates the destructive "renew identifier" setting, offline included.
    if (acc != null) UserSettings.instance.accountHasEmail = !acc.isAnonymous;
    if (!mounted) return;
    setState(() {
      _account = acc;
      _loading = false;
      _failed = acc == null;
    });
  }

  /// Manual run of the automatic sync. The account snapshot is reloaded after
  /// it: the counters shown here come from the server, so they only move once
  /// the queued changes have actually been delivered.
  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final svc = SyncService.instance;
    await svc.syncNow(force: true);
    if (!mounted) return;
    await _refreshPending();
    AppSnack.showOn(messenger,
        svc.lastError == null ? l10n.accountSyncDone : l10n.accountSyncFailed);
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _startEmailFlow() async {
    final acc = _account;
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _EmailLoginScreen(
        // Local data at stake if this address already has an account: what the
        // merge confirmation is sized on.
        localItems: (acc?.librarySongs ?? 0) + (acc?.libraryAlbums ?? 0),
      ),
    ));
    if (done == true && mounted) {
      setState(() => _loading = true);
      await _load();
    }
  }

  /// The public pen name (migration 193). Two things make it more than a text
  /// field: it is UNIQUE across accounts (the guard against signing someone
  /// else's name), and CHANGING it unpublishes every playlist already approved
  /// until they are reviewed again — which the user has to know before
  /// confirming, not after watching them disappear.
  Future<void> _editDisplayName() async {
    final result =
        await showDisplayNameDialog(context, current: _account?.displayName);
    if (result == null || !mounted) return;
    final l10n = context.l10n;
    AppSnack.show(
        context,
        result.playlistsBackInReview > 0
            ? l10n.accountDisplayNameBackInReview(result.playlistsBackInReview)
            : l10n.accountDisplayNameSaved);
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final email = _account?.email ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountSignOutTitle),
        content: Text(l10n.accountSignOutBody(email)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.accountSignOut)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await UserSettings.instance.clearUserId();
    UserSettings.instance.accountHasEmail = false;
    // A device without an id is not a valid state: take a fresh anonymous one
    // right away so favourites and history keep being recorded.
    final fresh = await RewampDb.registerUser();
    if (fresh != null && fresh.isNotEmpty) {
      await UserSettings.instance.setUserId(fresh);
      // Everything account-scoped still points at the account just left: the
      // delta cursors, and the server link of every synced playlist. Re-bind
      // them to the new one — and re-publish the device's library, which is
      // what a device carries whoever it speaks for. Signing out is not a
      // deletion: nothing local is thrown away here.
      await SyncService.instance.rebindLocalDataToCurrentAccount(
          action: LocalDataAction.keepUnpublished);
    }
    if (!mounted) return;
    AppSnack.show(context, l10n.accountSignedOut);
    setState(() => _loading = true);
    await _load();
  }

  /// "Log out everywhere": invalidates every token of the account. This device
  /// adopts the fresh one the call returns, so it stays signed in while the
  /// others are dropped on their next request — the answer to a lost or sold
  /// device, and the only per-account revocation there is (rotating the server
  /// secret would disconnect every user of the app).
  Future<void> _revokeSessions() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountRevoke),
        content: Text(l10n.accountRevokeBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.accountRevoke)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final id = await RewampDb.revokeSessions();
      if (id != null && id.isNotEmpty) {
        await UserSettings.instance.setUserId(id);
      }
      if (!mounted) return;
      AppSnack.show(context, l10n.accountRevokeDone);
    } catch (e) {
      if (!mounted) return;
      AppSnack.show(context, l10n.accountErrorNetwork);
    }
  }

  /// ERASES the account server-side (§2.5 of the spec). Deliberately far from
  /// [_signOut] in both code and UI: signing out keeps everything and is
  /// reversible with a code, this destroys it. The counts shown come from the
  /// snapshot already on screen, so the user reads what they are about to lose.
  ///
  /// The device's OWN library is not touched — deleting the account removes the
  /// server copy, and nothing here re-uploads it to the fresh anonymous account
  /// that replaces it (that is what makes the deletion mean anything).
  Future<void> _deleteAccount() async {
    final l10n = context.l10n;
    final acc = _account;
    final items = (acc?.librarySongs ?? 0) + (acc?.libraryAlbums ?? 0);
    final lists = (acc?.playlists ?? 0) + (acc?.libraryPlaylists ?? 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountDelete),
        content: Text('${l10n.accountDeleteBody(items, lists)}\n\n'
            '${l10n.accountDeleteKeepsLocal}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.accountDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final removed = await RewampDb.deleteAccount();
      debugPrint('[AccountScreen] account deleted, removed=$removed');
      // The token now designates a row that no longer exists: drop it, and take
      // a fresh anonymous account so favourites and history keep being
      // recorded. The cursors belonged to the deleted account.
      await UserSettings.instance.clearUserId();
      UserSettings.instance.accountHasEmail = false;
      final fresh = await RewampDb.registerUser();
      if (fresh != null && fresh.isNotEmpty) {
        await UserSettings.instance.setUserId(fresh);
        // Cursors reset and playlist links dropped — those pointed at an
        // account that no longer exists, and pushing to it would answer
        // `23503 unknown playlist` for ever. Nothing is published: the user
        // asked for the server copy to be gone, so re-uploading it to the
        // replacement account would empty the gesture of its meaning. The
        // local library stays on the device.
        await SyncService.instance.rebindLocalDataToCurrentAccount(
            action: LocalDataAction.keepUnpublished);
      }
      if (!mounted) return;
      AppSnack.show(context, l10n.accountDeleteDone);
      setState(() => _loading = true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnack.show(context, l10n.accountErrorNetwork);
    }
  }

  Future<void> _detachEmail() async {
    final l10n = context.l10n;
    if (!UserSettings.instance.hasAuthToken) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountDetach),
        content: Text(l10n.accountDetachBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.accountDetach)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await RewampDb.detachEmail();
      UserSettings.instance.accountHasEmail = false;
      if (!mounted) return;
      AppSnack.show(context, l10n.accountDetachDone);
      setState(() => _loading = true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnack.show(context, l10n.accountErrorNetwork);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_failed ? _errorBody(context) : _body(context)),
    );
  }

  Widget _errorBody(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(l10n.accountOffline),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () { setState(() => _loading = true); _load(); },
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final acc = _account!;
    final anon = acc.isAnonymous;
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale);
    final nf = NumberFormat.decimalPattern(locale);

    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(anon ? Icons.person_outline : Icons.verified_user_outlined,
              color: cs.primary, size: 32),
          title: Text(anon ? l10n.accountAnonymous : acc.email!,
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(anon
              ? l10n.accountAnonymousExplain
              : (acc.emailVerified
                  ? l10n.accountEmailAttached
                  : l10n.accountEmailPending)),
          isThreeLine: anon,
        ),
        if (UserSettings.instance.userIdInsecureFallback)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined, color: cs.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.accountInsecureStorage,
                      style: TextStyle(color: cs.error, fontSize: 12)),
                ),
              ],
            ),
          ),
        if (anon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FilledButton.icon(
              onPressed: _startEmailFlow,
              icon: const Icon(Icons.mail_outline),
              label: Text(l10n.accountSaveCta),
            ),
          ),
        // Sits right under the email: both answer "who am I here?", except this
        // one is the name OTHERS see on a published playlist.
        ListTile(
          leading: Icon(Icons.badge_outlined, color: cs.primary),
          title: Text(l10n.accountDisplayName),
          subtitle: Text(acc.displayName ?? l10n.accountDisplayNameNotSet),
          trailing: const Icon(Icons.chevron_right),
          onTap: _editDisplayName,
        ),
        const Divider(height: 24),
        // Label + bare number rather than "{n} tracks": a noun injected into a
        // counted sentence declines with the number in ru/pl/cs.
        _statTile(Icons.music_note_outlined, l10n.accountStatSongs,
            nf.format(acc.librarySongs)),
        _statTile(Icons.album_outlined, l10n.accountStatAlbums,
            nf.format(acc.libraryAlbums)),
        // Owned + saved playlists in one line: the user does not care which
        // side of the server model a playlist sits on.
        _statTile(Icons.queue_music_outlined, l10n.accountStatPlaylists,
            nf.format(acc.playlists + acc.libraryPlaylists)),
        _statTile(Icons.play_circle_outline, l10n.accountStatPlays,
            nf.format(acc.plays)),
        if (acc.createdAt != null)
          _statTile(Icons.event_outlined, l10n.accountCreatedLabel,
              df.format(acc.createdAt!.toLocal())),
        const Divider(height: 24),
        // Sync runs on its own (launch, back to foreground, after a change).
        // This is the "I want it now" button, plus the only place that says
        // whether anything is still waiting to be delivered.
        ListenableBuilder(
          listenable: SyncService.instance,
          builder: (context, _) {
            final svc = SyncService.instance;
            return ListTile(
              leading: svc.isRunning
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_sync_outlined),
              title: Text(l10n.accountSyncNow),
              // An anonymous account cannot be reached from another device, so
              // there is nothing to synchronise WITH: what runs is a backup of
              // this device's library. Say that rather than let the word "sync"
              // promise something an email would be needed for.
              subtitle: Text(_pending > 0
                  ? l10n.accountSyncPending
                  : anon
                      ? l10n.accountSyncAnonymous
                      : (svc.lastSuccess != null
                          ? l10n.accountSyncLast(
                              DateFormat.yMMMd(locale).add_Hm()
                                  .format(svc.lastSuccess!.toLocal()))
                          : l10n.accountSyncAuto)),
              onTap: svc.isRunning ? null : () => _syncNow(),
            );
          },
        ),
        const Divider(height: 24),
        if (!anon) ...[
          ListTile(
            leading: const Icon(Icons.devices_other_outlined),
            title: Text(l10n.accountRevoke),
            subtitle: Text(l10n.accountRevokeSubtitle),
            onTap: _revokeSessions,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.accountSignOut),
            subtitle: Text(l10n.accountSignOutSubtitle),
            onTap: _signOut,
          ),
          ListTile(
            leading: Icon(Icons.link_off, color: cs.error),
            title: Text(l10n.accountDetach, style: TextStyle(color: cs.error)),
            subtitle: Text(l10n.accountDetachSubtitle),
            onTap: _detachEmail,
          ),
        ] else
          // Deliberately NOT offering a sign-out here: clearing an id that no
          // email can bring back destroys the account for good.
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.accountNoSignOut),
            subtitle: Text(l10n.accountNoSignOutSubtitle),
          ),
        // Account deletion sits ON ITS OWN, below a wide gap: the spec is
        // explicit that it must not share a screen area (nor a colour) with
        // signing out, which keeps everything and is undone with a code.
        const SizedBox(height: 24),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: cs.error),
          title: Text(l10n.accountDelete, style: TextStyle(color: cs.error)),
          subtitle: Text(l10n.accountDeleteSubtitle),
          onTap: _deleteAccount,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _statTile(IconData icon, String label, String value) => ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(label),
        trailing: Text(value),
      );
}

/// Two-step email flow: address → 6-digit code. Kept on its own route so the
/// account screen never has to model a half-entered login.
class _EmailLoginScreen extends StatefulWidget {
  final int localItems;
  const _EmailLoginScreen({required this.localItems});

  @override
  State<_EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<_EmailLoginScreen> {
  final _emailCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;

  /// Carry this device's favourites and playlists into the account being
  /// joined. ON by default: it is the non-destructive choice, and it is what
  /// the server's own merge does. Turning it OFF is the "switch accounts
  /// cleanly on this device" case — the local ones are dropped and the joined
  /// account's take their place.
  bool _carryLocal = true;

  /// Seconds left before "resend" is allowed again (the mail takes ~40 s to
  /// arrive in production, so an instant resend button only doubles the codes).
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    final l10n = context.l10n;
    final email = _emailCtl.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _error = l10n.accountErrorInvalidEmail);
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await RewampDb.requestLoginCode(email);
      if (!mounted) return;
      setState(() { _busy = false; _codeStep = true; });
      _startResendCooldown();
    } on RewampRpcException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.isRateLimited
            ? l10n.accountErrorTooMany
            : (e.isInvalidEmail
                ? l10n.accountErrorInvalidEmail
                : l10n.accountErrorNetwork);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _error = l10n.accountErrorNetwork; });
    }
  }

  Future<void> _verify() async {
    final l10n = context.l10n;
    final code = _codeCtl.text.trim();
    if (code.length != 6) {
      setState(() => _error = l10n.accountErrorCodeLength);
      return;
    }
    // Both answers to the checkbox deserve a confirmation when this device
    // holds something: keeping is irreversible server-side (the anonymous row
    // is deleted by the merge), dropping is irreversible locally. Same dialog,
    // the text follows the choice — and the destructive one is coloured.
    if (widget.localItems > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_carryLocal
              ? l10n.accountMergeTitle
              : l10n.accountDropLocalTitle),
          content: Text(_carryLocal
              ? l10n.accountMergeBody(_emailCtl.text.trim())
              : l10n.accountCarryLocalOff),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel)),
            FilledButton(
                style: _carryLocal
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_carryLocal
                    ? l10n.accountMergeConfirm
                    : l10n.accountVerify)),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      // What gets merged into the account is decided by THIS DEVICE'S TOKEN,
      // sent in the Authorization header (p_merge_from is gone — it let a
      // caller name someone else's account). verifyLoginCode also swaps the
      // stored token for the one it returns, so every later call speaks for the
      // account we just joined.
      final previous = UserSettings.instance.userId;
      final res = await RewampDb.verifyLoginCode(
        email: _emailCtl.text.trim(),
        code: code,
      );
      // The returned id IS the account from now on — on a second device it is a
      // different UUID than the one this install had, which is the point.
      await UserSettings.instance.setUserId(res.userId);
      UserSettings.instance.accountHasEmail = true;
      // Landing on a DIFFERENT account (the normal case, and the only case when
      // switching accounts on one device) leaves every account-scoped local
      // value pointing at the previous one: the delta cursors would hide the
      // joined account's older rows for ever, and each synced playlist would
      // keep answering `42501 not your playlist`. Re-bind, and let the device's
      // library reach the account it now belongs to — the same thing the
      // server's own merge does for what the anonymous row held.
      if (previous != null && previous != res.userId) {
        await SyncService.instance.rebindLocalDataToCurrentAccount(
            action: _carryLocal
                ? LocalDataAction.publish
                : LocalDataAction.drop);
      }
      if (!mounted) return;
      final msg = res.created
          ? l10n.accountCreatedOk
          : (res.merged ? l10n.accountMergedOk : l10n.accountSignedInOk);
      Navigator.of(context).pop(true);
      AppSnack.show(context, msg);
    } on RewampRpcException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.isInvalidCode
            ? l10n.accountErrorInvalidCode
            : l10n.accountErrorNetwork;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _error = l10n.accountErrorNetwork; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(_codeStep ? l10n.accountCodeTitle : l10n.accountEmailTitle)),
      body: ListView(
        padding: shellInset(context, const EdgeInsets.all(16)),
        children: [
          Text(_codeStep
              ? l10n.accountCodeExplain(_emailCtl.text.trim())
              : l10n.accountEmailExplain),
          const SizedBox(height: 16),
          if (!_codeStep)
            TextField(
              controller: _emailCtl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.accountEmailLabel,
                hintText: 'name@example.com',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _busy ? null : _sendCode(),
            )
          else
            TextField(
              controller: _codeCtl,
              autofocus: true,
              keyboardType: TextInputType.number,
              // The 6 digits are also in the mail's SUBJECT, which is what makes
              // the OS one-time-code autofill work.
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                labelText: l10n.accountCodeLabel,
                border: const OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _busy ? null : _verify(),
            ),
          // Only on the code step, and only when this device HAS something to
          // carry: on a blank install the choice is meaningless and the wording
          // ("your favourites will be added") would be a lie.
          if (_codeStep && widget.localItems > 0) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _carryLocal,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _carryLocal = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.accountCarryLocal),
              subtitle: Text(_carryLocal
                  ? l10n.accountCarryLocalOn(widget.localItems)
                  : l10n.accountCarryLocalOff),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : (_codeStep ? _verify : _sendCode),
            child: _busy
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_codeStep ? l10n.accountVerify : l10n.accountSendCode),
          ),
          if (_codeStep) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: (_busy || _resendIn > 0)
                  ? null
                  : () => _sendCode(resend: true),
              child: Text(_resendIn > 0
                  ? l10n.accountResendIn(_resendIn)
                  : l10n.accountResend),
            ),
            const SizedBox(height: 8),
            Text(l10n.accountCheckSpam,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
