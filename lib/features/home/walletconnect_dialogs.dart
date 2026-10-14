import 'package:flutter/material.dart';

import '../../core/models/walletconnect_summary.dart';
import '../../core/theme/launcher_palette.dart';
import 'launcher_controller.dart';

const _sharedExplanation =
    'Syrius stores its WalletConnect connections (pairings, sessions and '
    'their keys) in the macOS preferences, not in the profile folder. By '
    'default these connections are therefore shared by all wallet profiles '
    'and by your ordinary Syrius installation.';

enum WalletConnectNoticeChoice { proceed, options }

/// One-time warning shown before the first launch.
Future<WalletConnectNoticeChoice?> showWalletConnectNoticeDialog(
  BuildContext context,
) {
  return showDialog<WalletConnectNoticeChoice>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('WalletConnect is shared'),
      content: const SizedBox(
        width: 380,
        child: Text(
          '$_sharedExplanation\n\n'
          'A dApp connected while one profile is running can still be known '
          'when another profile runs. Check which wallet a request is for '
          'before approving it in Syrius, or clear WalletConnect data before '
          'each launch.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(WalletConnectNoticeChoice.options),
          child: const Text('WalletConnect options...'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(WalletConnectNoticeChoice.proceed),
          child: const Text('I understand'),
        ),
      ],
    ),
  );
}

Future<void> showWalletConnectDialog(
  BuildContext context, {
  required LauncherController controller,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _WalletConnectDialog(controller: controller),
  );
}

class _WalletConnectDialog extends StatefulWidget {
  const _WalletConnectDialog({required this.controller});

  final LauncherController controller;

  @override
  State<_WalletConnectDialog> createState() => _WalletConnectDialogState();
}

class _WalletConnectDialogState extends State<_WalletConnectDialog> {
  WalletConnectSummary? _summary;
  bool _busy = false;
  String? _status;

  LauncherController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    try {
      final summary = await _controller.walletConnectSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      if (mounted) setState(() => _summary = null);
    }
  }

  Future<void> _setClearOnLaunch(bool value) async {
    setState(() => _busy = true);
    try {
      await _controller.setClearWalletConnectOnLaunch(value);
    } catch (error) {
      _status = '$error';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _clearNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Clear WalletConnect data'),
        content: const SizedBox(
          width: 360,
          child: Text(
            'This disconnects every dApp from Syrius, for all profiles and '
            'for your ordinary Syrius installation. Wallet files are not '
            'touched. You can reconnect dApps afterwards.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final removed = await _controller.clearWalletConnectNow();
      _status = removed == 0
          ? 'There was no WalletConnect data to clear.'
          : 'WalletConnect data cleared.';
    } catch (error) {
      _status = '$error';
    }
    await _refreshCount();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final running = _controller.isSyriusRunning;
        return AlertDialog(
          scrollable: true,
          title: const Text('WalletConnect'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(_sharedExplanation),
                const SizedBox(height: 10),
                _SummaryText(summary: _summary),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: _controller.clearWalletConnectOnLaunch,
                  onChanged: _busy ? null : _setClearOnLaunch,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: LauncherPalette.buttonText,
                  activeTrackColor: LauncherPalette.primaryGreen,
                  title: const Text(
                    'Clear WalletConnect data before each launch',
                    style: TextStyle(
                      color: LauncherPalette.headingText,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Every profile then starts without dApp connections.',
                    style: TextStyle(
                      color: LauncherPalette.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (running)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Syrius is running. Use "Exit wallet" inside Syrius '
                      'before clearing.',
                      style: TextStyle(
                        color: LauncherPalette.errorText,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _status!,
                      style: const TextStyle(
                        color: LauncherPalette.headingText,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy || running ? null : _clearNow,
              child: const Text('Clear WalletConnect data now...'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryText extends StatelessWidget {
  const _SummaryText({required this.summary});

  final WalletConnectSummary? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final String text;
    if (summary == null) {
      text = 'Stored connections: unknown';
    } else if (!summary.hasConnections) {
      text = 'No dApps are connected.';
    } else {
      text =
          'Stored connections: ${_plural(summary.sessions, 'session')}, '
          '${_plural(summary.pairings, 'pairing')}.';
    }
    return Text(
      text,
      style: const TextStyle(color: LauncherPalette.headingText),
    );
  }

  static String _plural(int count, String word) =>
      '$count $word${count == 1 ? '' : 's'}';
}
