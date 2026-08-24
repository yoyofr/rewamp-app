import 'package:flutter/material.dart';

import 'l10n.dart';
import 'rewamp_db.dart';

/// Shows the public-pen-name dialog. Lives on its own because two screens open
/// it: Settings (the field itself) and the playlists screen, where publishing is
/// refused until a name exists.
Future<DisplayNameResult?> showDisplayNameDialog(BuildContext context,
        {String? current}) =>
    showDialog<DisplayNameResult>(
      context: context,
      builder: (_) => DisplayNameDialog(current: current),
    );

/// Picking the public pen name. Does its own RPC so the two failures that
/// matter can be answered IN the field instead of closing on a snack: 23505
/// (already taken — the point of the uniqueness constraint) and 23514 (outside
/// 2–40 characters, also checked here so the round trip is not needed).
class DisplayNameDialog extends StatefulWidget {
  final String? current;
  const DisplayNameDialog({super.key, this.current});

  @override
  State<DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<DisplayNameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.current ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _ctrl.text.trim();
    if (name.length < 2 || name.length > 40) {
      setState(() => _error = l10n.accountDisplayNameLength);
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final res = await RewampDb.setDisplayName(name);
      if (mounted) Navigator.pop(context, res);
    } on RewampRpcException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == '23505'
            ? l10n.accountDisplayNameTaken
            : (e.code == '23514'
                ? l10n.accountDisplayNameLength
                : l10n.accountErrorNetwork);
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
    // Only a CHANGE costs anything: the first name published nothing yet.
    final isChange = (widget.current ?? '').isNotEmpty;
    return AlertDialog(
      title: Text(l10n.accountDisplayName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountDisplayNameHint,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 40,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          if (isChange)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined, color: cs.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.accountDisplayNameChangeWarning,
                      style: TextStyle(color: cs.error, fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l10n.commonCancel)),
        FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(l10n.commonSave)),
      ],
    );
  }
}
