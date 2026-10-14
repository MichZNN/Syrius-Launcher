import 'package:flutter/material.dart';

import '../../core/models/wallet_profile.dart';
import '../../core/theme/launcher_palette.dart';
import 'wallet_profile_tile.dart';

/// Presentational home screen (spec 4.1 / 4.2 / 4.7). Cards are generated
/// only from [profiles]; an empty list renders the empty state.
class LauncherHomeView extends StatelessWidget {
  const LauncherHomeView({
    super.key,
    required this.profiles,
    required this.selectedId,
    required this.runningProfileId,
    required this.canLaunch,
    required this.launching,
    required this.onSelect,
    required this.onLaunch,
    required this.onAdd,
    required this.onMenuAction,
  });

  final List<WalletProfile> profiles;
  final String? selectedId;
  final String? runningProfileId;
  final bool canLaunch;
  final bool launching;
  final ValueChanged<String> onSelect;
  final VoidCallback onLaunch;
  final VoidCallback onAdd;
  final void Function(WalletProfile profile, ProfileMenuAction action)
  onMenuAction;

  @override
  Widget build(BuildContext context) {
    final hasSelection = profiles.any((profile) => profile.id == selectedId);
    return Scaffold(
      backgroundColor: LauncherPalette.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 22),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: LauncherPalette.separator,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: profiles.isEmpty
                      ? const _EmptyState()
                      : _ProfileList(
                          profiles: profiles,
                          selectedId: selectedId,
                          runningProfileId: runningProfileId,
                          onSelect: onSelect,
                          onMenuAction: onMenuAction,
                        ),
                ),
                const SizedBox(height: 20),
                _LaunchButton(
                  enabled: canLaunch && hasSelection && !launching,
                  launching: launching,
                  onPressed: onLaunch,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add wallet profile'),
                    style: TextButton.styleFrom(
                      foregroundColor: LauncherPalette.secondaryText,
                      textStyle: const TextStyle(fontSize: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: LauncherPalette.headerIconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: LauncherPalette.primaryGreen,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Syrius Launcher',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: LauncherPalette.headingText,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Select your wallet profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: LauncherPalette.headerSubtitle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: LauncherPalette.secondaryText,
              size: 38,
            ),
            SizedBox(height: 16),
            Text(
              'No wallet profiles yet',
              style: TextStyle(
                color: LauncherPalette.headingText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Create a profile to get started',
              style: TextStyle(
                color: LauncherPalette.secondaryText,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({
    required this.profiles,
    required this.selectedId,
    required this.runningProfileId,
    required this.onSelect,
    required this.onMenuAction,
  });

  final List<WalletProfile> profiles;
  final String? selectedId;
  final String? runningProfileId;
  final ValueChanged<String> onSelect;
  final void Function(WalletProfile profile, ProfileMenuAction action)
  onMenuAction;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return WalletProfileTile(
          key: ValueKey(profile.id),
          profile: profile,
          selected: profile.id == selectedId,
          running: profile.id == runningProfileId,
          onSelect: () => onSelect(profile.id),
          onMenuAction: (action) => onMenuAction(profile, action),
        );
      },
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({
    required this.enabled,
    required this.launching,
    required this.onPressed,
  });

  final bool enabled;
  final bool launching;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style:
            FilledButton.styleFrom(
              backgroundColor: LauncherPalette.primaryGreen,
              disabledBackgroundColor: LauncherPalette.disabledButton,
              foregroundColor: LauncherPalette.buttonText,
              disabledForegroundColor: LauncherPalette.buttonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? const BorderSide(
                        color: LauncherPalette.headingText,
                        width: 2,
                      )
                    : BorderSide.none,
              ),
            ),
        icon: launching
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: LauncherPalette.buttonText,
                ),
              )
            : const Icon(Icons.play_arrow_rounded, size: 20),
        label: Text(
          launching ? 'Launching...' : 'Launch Syrius',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
