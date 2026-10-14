import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/launch_status.dart';
import '../models/walletconnect_summary.dart';
import '../models/wallet_profile.dart';
import '../services/syrius_locator.dart';
import 'macos_native_bridge.dart';
import 'syrius_platform_launcher.dart';

class MacosSyriusLauncher implements SyriusPlatformLauncher {
  MacosSyriusLauncher({
    this._bridge = const MacosNativeBridge(),
    String? homeDirectory,
  }) : _home = homeDirectory ?? Platform.environment['HOME']! {
    _locator = SyriusLocator(inspector: _bridge, homeDirectory: _home);
  }

  final MacosNativeBridge _bridge;
  final String _home;
  late final SyriusLocator _locator;

  /// Last validated executable name, used for the `pgrep` fallback.
  String _executableName = 's y r i u s';

  @override
  bool get isSupported => true;

  @override
  String sdkRootForHome(String homePath) => p.join(homePath, 'Library', 'znn');

  @override
  String get defaultSdkRoot => sdkRootForHome(_home);

  @override
  Future<SyriusInstallation?> discoverInstallation({
    String? savedAppPath,
  }) async {
    final known = await _bridge.applicationsForBundleIdentifier(
      SyriusLocator.bundleIdentifier,
    );
    final installation = await _locator.discover(
      savedPath: savedAppPath,
      launchServicesPaths: known,
    );
    if (installation != null) _executableName = installation.executableName;
    return installation;
  }

  @override
  Future<SyriusInstallation> validateInstallation(String appPath) async {
    final installation = await _locator.validate(appPath);
    _executableName = installation.executableName;
    return installation;
  }

  @override
  Future<String?> pickInstallation() => _bridge.pickApplication();

  @override
  Future<LaunchHandle> launch({
    required SyriusInstallation installation,
    required WalletProfile profile,
    required String homePath,
  }) async {
    final binary = File(installation.executablePath);
    final home = Directory(homePath);
    if (!await binary.exists() || !await home.exists()) {
      throw StateError('Syrius executable or profile root is missing');
    }

    // Started directly (never via `open -a`, which can reuse a running
    // instance with the wrong HOME). No shell is involved, so the spaces in
    // "s y r i u s" need no quoting.
    //
    // Detached on purpose: the child gets no stdio pipes, so Syrius output is
    // never captured or logged, and Syrius cannot be killed by SIGPIPE when
    // the launcher quits first. Liveness is tracked by pid instead.
    final process = await Process.start(
      binary.path,
      const [],
      workingDirectory: p.dirname(binary.path),
      environment: {'HOME': home.absolute.path},
      includeParentEnvironment: true,
      runInShell: false,
      mode: ProcessStartMode.detached,
    );
    return LaunchHandle(
      pid: process.pid,
      profileId: profile.id,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<Set<int>> runningSyriusPids() async {
    final pids = await _bridge.runningProcessIds(
      SyriusLocator.bundleIdentifier,
    );
    // Fallback for instances Launch Services does not report (for example a
    // copy with a modified bundle id): match the exact process name.
    final result = await Process.run('/usr/bin/pgrep', ['-x', _executableName]);
    if (result.exitCode == 0) {
      for (final line in (result.stdout as String).split('\n')) {
        final pid = int.tryParse(line.trim());
        if (pid != null) pids.add(pid);
      }
    }
    return pids;
  }

  @override
  Future<bool> isAnySyriusRunning() async =>
      (await runningSyriusPids()).isNotEmpty;

  @override
  Future<WalletConnectSummary> walletConnectSummary() =>
      _bridge.walletConnectSummary();

  @override
  Future<int> clearWalletConnectData() => _bridge.clearWalletConnectData();

  @override
  Future<void> openOfficialReleases() => _bridge.openUrl(officialReleasesUrl);
}
