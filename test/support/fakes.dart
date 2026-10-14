import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:syrius_launcher/core/models/launch_status.dart';
import 'package:syrius_launcher/core/models/launcher_settings.dart';
import 'package:syrius_launcher/core/models/wallet_profile.dart';
import 'package:syrius_launcher/core/models/walletconnect_summary.dart';
import 'package:syrius_launcher/core/persistence/profile_repository.dart';
import 'package:syrius_launcher/core/platform/syrius_platform_launcher.dart';
import 'package:syrius_launcher/core/services/profile_service.dart';
import 'package:syrius_launcher/core/services/syrius_locator.dart';

class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository([this.stored]);

  LauncherSettings? stored;
  int saveCount = 0;
  bool failNextSave = false;
  bool corrupt = false;
  bool quarantined = false;

  @override
  Future<LauncherSettings> load() async {
    if (corrupt) throw const MetadataException('broken');
    return stored ?? const LauncherSettings.empty();
  }

  @override
  Future<void> save(LauncherSettings settings) async {
    if (failNextSave) {
      failNextSave = false;
      throw const FileSystemException('disk full');
    }
    saveCount++;
    stored = settings;
  }

  @override
  Future<String?> quarantine() async {
    quarantined = true;
    corrupt = false;
    return '/tmp/profiles.json.invalid';
  }
}

/// Moves items into [trashDir] instead of the real Trash.
class FakeTrash implements ProfileTrash {
  FakeTrash(this.trashDir);

  final Directory trashDir;
  final trashed = <String>[];
  bool fail = false;

  @override
  Future<String?> moveToTrash(String path) async {
    if (fail) throw const TrashException('Trash unavailable');
    final target = p.join(trashDir.path, p.basename(path));
    await Directory(path).rename(target);
    trashed.add(path);
    return target;
  }
}

class FakeBundleInspector implements BundleInspector {
  final bundles = <String, BundleInfo>{};

  @override
  Future<BundleInfo?> inspect(String appPath) async => bundles[appPath];
}

class FakePlatformLauncher implements SyriusPlatformLauncher {
  FakePlatformLauncher({required this.home});

  final String home;
  SyriusInstallation? installation = const SyriusInstallation(
    appPath: '/Applications/s y r i u s.app',
    executablePath: '/Applications/s y r i u s.app/Contents/MacOS/s y r i u s',
    executableName: 's y r i u s',
    version: 'v0.2.4-alphanet',
  );
  Set<int> running = {};
  int nextPid = 4242;
  bool exitImmediately = false;
  Object? launchError;
  final launches = <({String profileId, String homePath})>[];

  @override
  bool get isSupported => true;

  @override
  String sdkRootForHome(String homePath) => p.join(homePath, 'Library', 'znn');

  @override
  String get defaultSdkRoot => sdkRootForHome(home);

  @override
  Future<SyriusInstallation?> discoverInstallation({
    String? savedAppPath,
  }) async => installation;

  @override
  Future<SyriusInstallation> validateInstallation(String appPath) async =>
      installation ?? (throw const SyriusInstallationException('not found'));

  @override
  Future<String?> pickInstallation() async => installation?.appPath;

  @override
  Future<LaunchHandle> launch({
    required SyriusInstallation installation,
    required WalletProfile profile,
    required String homePath,
  }) async {
    if (launchError != null) throw launchError!;
    launches.add((profileId: profile.id, homePath: homePath));
    final pid = nextPid++;
    if (!exitImmediately) running = {...running, pid};
    return LaunchHandle(
      pid: pid,
      profileId: profile.id,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<Set<int>> runningSyriusPids() async => {...running};

  @override
  Future<bool> isAnySyriusRunning() async => running.isNotEmpty;

  WalletConnectSummary walletConnect = WalletConnectSummary.empty;
  int clearCalls = 0;
  Object? clearError;

  @override
  Future<WalletConnectSummary> walletConnectSummary() async => walletConnect;

  @override
  Future<int> clearWalletConnectData() async {
    if (clearError != null) throw clearError!;
    clearCalls++;
    final removed = walletConnect.storageKeys;
    walletConnect = WalletConnectSummary.empty;
    return removed;
  }

  @override
  Future<void> openOfficialReleases() async {}
}
