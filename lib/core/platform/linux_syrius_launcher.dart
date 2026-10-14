import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/launch_status.dart';
import '../models/walletconnect_summary.dart';
import '../models/wallet_profile.dart';
import '../services/syrius_locator.dart';
import 'syrius_platform_launcher.dart';

/// Stub until Linux is implemented and tested separately (SDK root is
/// `HOME/.znn`).
class LinuxSyriusLauncher implements SyriusPlatformLauncher {
  const LinuxSyriusLauncher();

  @override
  bool get isSupported => false;

  @override
  String sdkRootForHome(String homePath) => p.join(homePath, '.znn');

  @override
  String get defaultSdkRoot =>
      sdkRootForHome(Platform.environment['HOME'] ?? '');

  @override
  Future<SyriusInstallation?> discoverInstallation({
    String? savedAppPath,
  }) async => null;

  @override
  Future<SyriusInstallation> validateInstallation(String appPath) async =>
      throw const SyriusInstallationException(
        'Launching Syrius is not supported on Linux yet.',
      );

  @override
  Future<String?> pickInstallation() async => null;

  @override
  Future<LaunchHandle> launch({
    required SyriusInstallation installation,
    required WalletProfile profile,
    required String homePath,
  }) async => throw UnsupportedError('Linux launching is not implemented yet');

  @override
  Future<Set<int>> runningSyriusPids() async => {};

  @override
  Future<bool> isAnySyriusRunning() async => false;

  @override
  Future<WalletConnectSummary> walletConnectSummary() async =>
      WalletConnectSummary.empty;

  @override
  Future<int> clearWalletConnectData() async =>
      throw UnsupportedError('Not implemented on Linux yet');

  @override
  Future<void> openOfficialReleases() async {}
}
