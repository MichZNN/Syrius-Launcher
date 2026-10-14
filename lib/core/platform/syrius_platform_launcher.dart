import 'dart:io';

import '../models/launch_status.dart';
import '../models/walletconnect_summary.dart';
import '../models/wallet_profile.dart';
import '../services/syrius_locator.dart';
import 'linux_syrius_launcher.dart';
import 'macos_syrius_launcher.dart';
import 'windows_syrius_launcher.dart';

/// Owns everything platform-specific about finding and starting Syrius.
/// Widgets and services never check `Platform.isMacOS` themselves.
abstract interface class SyriusPlatformLauncher {
  /// Whether launching is implemented and supported on this platform.
  bool get isSupported;

  /// The Syrius SDK data root for a given HOME, e.g. `<home>/Library/znn` on
  /// macOS (znn_sdk_dart v0.0.7, lib/src/global.dart).
  String sdkRootForHome(String homePath);

  /// The real user's ordinary Syrius data root, which must never be touched.
  String get defaultSdkRoot;

  Future<SyriusInstallation?> discoverInstallation({String? savedAppPath});

  /// Throws [SyriusInstallationException] when [appPath] is not acceptable.
  Future<SyriusInstallation> validateInstallation(String appPath);

  /// Lets the user pick an installed app. Returns null when cancelled.
  Future<String?> pickInstallation();

  /// Starts the real Syrius executable with HOME set to [homePath] for the
  /// child process only.
  Future<LaunchHandle> launch({
    required SyriusInstallation installation,
    required WalletProfile profile,
    required String homePath,
  });

  /// Process ids of every running Syrius instance, including instances that
  /// were started outside the launcher.
  Future<Set<int>> runningSyriusPids();

  Future<bool> isAnySyriusRunning();

  /// Sessions and pairings in Syrius's shared preferences store. On macOS
  /// this store is shared by every profile and by the ordinary Syrius
  /// installation; HOME does not redirect it.
  Future<WalletConnectSummary> walletConnectSummary();

  /// Removes only WalletConnect keys from that store. Must only be called
  /// while no Syrius instance is running. Returns the number of keys
  /// removed.
  Future<int> clearWalletConnectData();

  Future<void> openOfficialReleases();
}

const officialReleasesUrl = 'https://github.com/zenon-network/syrius/releases';

SyriusPlatformLauncher createPlatformLauncher() {
  if (Platform.isMacOS) return MacosSyriusLauncher();
  if (Platform.isWindows) return const WindowsSyriusLauncher();
  return const LinuxSyriusLauncher();
}
