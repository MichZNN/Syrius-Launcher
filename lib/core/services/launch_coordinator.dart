import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/launch_status.dart';
import '../models/launcher_settings.dart';
import '../models/wallet_profile.dart';
import '../platform/syrius_platform_launcher.dart';
import 'profile_service.dart';
import 'syrius_locator.dart';

/// Runs every pre-launch check and starts Syrius for one profile.
class LaunchCoordinator {
  LaunchCoordinator({
    required this._platform,
    required this._profiles,
    this.earlyExitWindow = const Duration(seconds: 3),
  });

  final SyriusPlatformLauncher _platform;
  final ProfileService _profiles;

  /// How long to watch a fresh process before reporting it as started.
  final Duration earlyExitWindow;

  Future<LaunchResult> launch(
    WalletProfile profile, {
    bool firstRunConfirmed = false,
  }) async {
    if (!_platform.isSupported) {
      return const LaunchFailed(
        'Launching Syrius is not supported on this platform yet.',
      );
    }

    final installation = await _platform.discoverInstallation(
      savedAppPath: _profiles.settings.syriusAppPath,
    );
    if (installation == null) return const LaunchSyriusNotFound();
    if (installation.appPath != _profiles.settings.syriusAppPath) {
      await _profiles.setSyriusAppPath(installation.appPath);
    }

    if (await _platform.isAnySyriusRunning()) {
      return const LaunchBlockedAlreadyRunning();
    }

    final String home;
    try {
      home = _profiles.homeFor(profile.id);
    } on ProfileOperationException catch (error) {
      return LaunchFailed(error.message);
    }
    final homeType = await FileSystemEntity.type(home, followLinks: false);
    if (homeType != FileSystemEntityType.directory) {
      return LaunchFailed(
        'The folder for "${profile.name}" is missing or is not a regular '
        'folder:\n$home',
      );
    }

    if (!firstRunConfirmed &&
        !await hasWalletData(profile) &&
        await Directory(_platform.defaultSdkRoot).exists()) {
      return const LaunchNeedsFirstRunChoice();
    }

    final LaunchHandle handle;
    try {
      handle = await _platform.launch(
        installation: installation,
        profile: profile,
        homePath: home,
      );
    } on ProcessException catch (error) {
      return LaunchFailed('Syrius could not be started: ${error.message}');
    } on Object catch (error) {
      return LaunchFailed('Syrius could not be started: $error');
    }

    try {
      await _profiles.setLastLaunch(
        LastLaunchRecord(profileId: profile.id, pid: handle.pid),
      );
    } on Object {
      // Only a hint for rediscovery after a launcher restart.
    }

    await Future<void>.delayed(earlyExitWindow);
    if (!(await _platform.runningSyriusPids()).contains(handle.pid)) {
      return const LaunchExitedEarly();
    }
    return LaunchStarted(handle);
  }

  /// Whether Syrius has created wallet files inside this profile.
  Future<bool> hasWalletData(WalletProfile profile) async {
    final sdkRoot = _platform.sdkRootForHome(_profiles.homeFor(profile.id));
    return directoryHasEntries(p.join(sdkRoot, 'wallet'));
  }

  /// Maps a saved pid back to a profile, but only when that pid is still a
  /// running Syrius process. Saved pids are otherwise untrusted.
  String? verifiedRunningProfileId(Set<int> runningPids) {
    final record = _profiles.settings.lastLaunch;
    if (record == null || !runningPids.contains(record.pid)) return null;
    return _profiles.settings.profileById(record.profileId)?.id;
  }

  Future<SyriusInstallation> locate(String appPath) async {
    final installation = await _platform.validateInstallation(appPath);
    await _profiles.setSyriusAppPath(installation.appPath);
    return installation;
  }
}
