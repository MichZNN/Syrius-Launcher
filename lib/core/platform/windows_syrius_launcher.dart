import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/launch_status.dart';
import '../models/wallet_profile.dart';
import '../services/syrius_locator.dart';
import 'syrius_platform_launcher.dart';

/// Stub until Windows is audited. Windows storage may also depend on
/// APPDATA / LOCALAPPDATA / USERPROFILE, so a HOME override is not enough.
class WindowsSyriusLauncher implements SyriusPlatformLauncher {
  const WindowsSyriusLauncher();

  @override
  bool get isSupported => false;

  @override
  String sdkRootForHome(String homePath) => p.join(homePath, 'AppData', 'znn');

  @override
  String get defaultSdkRoot =>
      sdkRootForHome(Platform.environment['USERPROFILE'] ?? '');

  @override
  Future<SyriusInstallation?> discoverInstallation({
    String? savedAppPath,
  }) async => null;

  @override
  Future<SyriusInstallation> validateInstallation(String appPath) async =>
      throw const SyriusInstallationException(
        'Launching Syrius is not supported on Windows yet.',
      );

  @override
  Future<String?> pickInstallation() async => null;

  @override
  Future<LaunchHandle> launch({
    required SyriusInstallation installation,
    required WalletProfile profile,
    required String homePath,
  }) async =>
      throw UnsupportedError('Windows launching is not implemented yet');

  @override
  Future<Set<int>> runningSyriusPids() async => {};

  @override
  Future<bool> isAnySyriusRunning() async => false;

  @override
  Future<void> openOfficialReleases() async {}
}
