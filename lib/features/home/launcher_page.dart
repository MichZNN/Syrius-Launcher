import 'package:flutter/material.dart';

import '../../core/models/launch_status.dart';
import '../../core/models/wallet_profile.dart';
import '../../core/theme/launcher_palette.dart';
import 'launcher_controller.dart';
import 'launcher_home_view.dart';
import 'profile_dialogs.dart';
import 'walletconnect_dialogs.dart';
import 'wallet_profile_tile.dart';

/// Connects [LauncherController] to [LauncherHomeView] and owns all dialogs.
class LauncherPage extends StatefulWidget {
  const LauncherPage({
    super.key,
    required this.controller,
    this.showPlatformMenus = false,
  });

  final LauncherController controller;

  /// Installs the native macOS menu bar (with "Locate Syrius..."). Disabled
  /// in widget tests.
  final bool showPlatformMenus;

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  LauncherController get _controller => widget.controller;
  bool _shownQuarantineNotice = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final backup = _controller.quarantinedMetadataPath;
    if (backup != null && !_shownQuarantineNotice) {
      _shownQuarantineNotice = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showMessageDialog(
          context,
          title: 'Profile list could not be read',
          message:
              'The launcher\'s profile list was unreadable and has been moved '
              'aside, so the launcher starts empty. No wallet files were '
              'touched; profile folders remain in ~/SyriusProfiles.\n\n'
              'Backup of the unreadable file:\n$backup',
        );
      });
    }
  }

  Future<void> _select(String id) async {
    final changed = await _guard(() => _controller.select(id));
    if (changed == false && mounted) await showAlreadyRunningDialog(context);
  }

  Future<void> _add() async {
    await showProfileFormDialog(
      context,
      onSubmit: (result) => _controller.createProfile(
        name: result.name,
        description: result.description,
        icon: result.icon,
      ),
    );
  }

  Future<void> _onMenuAction(
    WalletProfile profile,
    ProfileMenuAction action,
  ) async {
    switch (action) {
      case ProfileMenuAction.edit:
        await showProfileFormDialog(
          context,
          initial: profile,
          onSubmit: (result) => _controller.updateProfile(
            profile.id,
            name: result.name,
            description: result.description,
            icon: result.icon,
          ),
        );
      case ProfileMenuAction.remove:
        await _remove(profile);
    }
  }

  Future<void> _remove(WalletProfile profile) async {
    if (!_controller.canRemove(profile.id)) {
      await showMessageDialog(
        context,
        title: 'Syrius is running',
        message:
            'Profiles cannot be removed while Syrius is running. Use "Exit '
            'wallet" inside Syrius, then try again.',
      );
      return;
    }
    final hasWalletData =
        await _guard(() => _controller.hasWalletData(profile)) ?? true;
    if (!mounted) return;
    final confirmed = await showRemoveProfileDialog(
      context,
      profile: profile,
      hasWalletData: hasWalletData,
    );
    if (confirmed) await _guard(() => _controller.removeProfile(profile.id));
  }

  Future<void> _launch({bool firstRunConfirmed = false}) async {
    final result = await _controller.launchSelected(
      firstRunConfirmed: firstRunConfirmed,
    );
    if (!mounted) return;
    switch (result) {
      case LaunchStarted():
        break;
      case LaunchBlockedAlreadyRunning():
        await showAlreadyRunningDialog(context);
      case LaunchSyriusNotFound():
        await _handleSyriusNotFound();
      case LaunchNeedsWalletConnectNotice():
        final choice = await showWalletConnectNoticeDialog(context);
        if (!mounted) return;
        switch (choice) {
          case WalletConnectNoticeChoice.proceed:
            if (await _run(_controller.acknowledgeWalletConnectNotice)) {
              await _launch(firstRunConfirmed: firstRunConfirmed);
            }
          case WalletConnectNoticeChoice.options:
            if (await _run(_controller.acknowledgeWalletConnectNotice) &&
                mounted) {
              await _openWalletConnect();
            }
          case null:
            break;
        }
      case LaunchNeedsFirstRunChoice():
        final profile = _controller.selectedProfile;
        if (profile == null) return;
        final choice = await showFirstRunChoiceDialog(
          context,
          profile: profile,
        );
        if (!mounted) return;
        switch (choice) {
          case FirstRunChoice.setUp:
            await _launch(firstRunConfirmed: true);
          case FirstRunChoice.learn:
            await showExistingWalletHelpDialog(context);
          case null:
            break;
        }
      case LaunchExitedEarly():
        await showMessageDialog(
          context,
          title: 'Syrius stopped',
          message:
              'Syrius was started but closed again within a few seconds. It '
              'may have crashed or refused to start. Try again, or start '
              'Syrius manually to see what happens.',
        );
      case LaunchFailed(:final message):
        await showMessageDialog(
          context,
          title: 'Could not launch Syrius',
          message: message,
        );
    }
  }

  Future<void> _handleSyriusNotFound() async {
    final choice = await showSyriusNotFoundDialog(context);
    switch (choice) {
      case SyriusNotFoundChoice.locate:
        await _locate();
      case SyriusNotFoundChoice.download:
        await _guard(_controller.openOfficialReleases);
      case null:
        break;
    }
  }

  Future<void> _locate() async {
    final installation = await _guard(_controller.locateSyrius);
    if (installation == null || !mounted) return;
    await showMessageDialog(
      context,
      title: 'Syrius found',
      message:
          'Using ${installation.appPath}'
          '${installation.version != null ? ' (${installation.version})' : ''}.',
    );
  }

  Future<void> _openWalletConnect() =>
      showWalletConnectDialog(context, controller: _controller);

  /// Like [_guard] for actions without a result; returns whether it worked.
  Future<bool> _run(Future<void> Function() action) async =>
      await _guard(() async {
        await action();
        return true;
      }) ??
      false;

  /// Runs [action] and shows failures in a dialog instead of throwing.
  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (mounted) {
        await showMessageDialog(
          context,
          title: 'Something went wrong',
          message: '$error',
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.phase == LauncherPhase.initializing) {
          return const Scaffold(backgroundColor: LauncherPalette.background);
        }
        if (_controller.phase == LauncherPhase.error) {
          return _StartupError(message: _controller.initError ?? '');
        }
        return LauncherHomeView(
          profiles: _controller.profiles,
          selectedId: _controller.selectedProfileId,
          runningProfileId: _controller.runningProfileId,
          canLaunch: _controller.canLaunch,
          launching: _controller.isLaunching,
          onSelect: _select,
          onLaunch: _launch,
          onAdd: _add,
          onMenuAction: _onMenuAction,
        );
      },
    );

    if (!widget.showPlatformMenus) return page;
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Syrius Launcher',
          menus: [
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.about,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Locate Syrius...',
                  onSelected: _locate,
                ),
                PlatformMenuItem(
                  label: 'WalletConnect...',
                  onSelected: _openWalletConnect,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Window',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
      ],
      child: page,
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LauncherPalette.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: LauncherPalette.errorText,
                size: 32,
              ),
              const SizedBox(height: 12),
              const Text(
                'The launcher could not start',
                style: TextStyle(
                  color: LauncherPalette.headingText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: LauncherPalette.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
