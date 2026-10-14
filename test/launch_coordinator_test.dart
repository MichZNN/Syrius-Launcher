import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:syrius_launcher/core/models/launch_status.dart';
import 'package:syrius_launcher/core/models/wallet_profile.dart';
import 'package:syrius_launcher/core/models/walletconnect_summary.dart';
import 'package:syrius_launcher/core/services/launch_coordinator.dart';
import 'package:syrius_launcher/core/services/profile_service.dart';

import 'support/fakes.dart';

const _connected = WalletConnectSummary(
  sessions: 1,
  pairings: 1,
  storageKeys: 28,
);

void main() {
  late Directory temp;
  late String realHome;
  late InMemoryProfileRepository repository;
  late ProfileService profiles;
  late FakePlatformLauncher platform;
  late LaunchCoordinator coordinator;
  late WalletProfile profile;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('launcher_coord_');
    realHome = p.join(temp.path, 'home');
    repository = InMemoryProfileRepository();
    profiles = ProfileService(
      repository: repository,
      profilesRootPath: p.join(realHome, 'SyriusProfiles'),
      trash: FakeTrash(await Directory(p.join(temp.path, 'trash')).create()),
    );
    platform = FakePlatformLauncher(home: realHome);
    coordinator = LaunchCoordinator(
      platform: platform,
      profiles: profiles,
      earlyExitWindow: Duration.zero,
    );
    profile = await profiles.create(
      name: 'Test',
      description: '',
      icon: ProfileIcon.wallet,
    );
    await profiles.acknowledgeWalletConnectNotice();
  });

  tearDown(() => temp.delete(recursive: true));

  test('launches with HOME set to the profile folder', () async {
    final result = await coordinator.launch(profile);

    expect(result, isA<LaunchStarted>());
    expect(platform.launches.single.homePath, profiles.homeFor(profile.id));
    expect(platform.launches.single.homePath, isNot(realHome));
    expect(repository.stored!.lastLaunch?.pid, 4242);
    expect(repository.stored!.syriusAppPath, '/Applications/s y r i u s.app');
  });

  test('reports a missing Syrius installation', () async {
    platform.installation = null;
    expect(await coordinator.launch(profile), isA<LaunchSyriusNotFound>());
    expect(platform.launches, isEmpty);
  });

  test('blocks when any Syrius process is already running', () async {
    platform.running = {999};
    expect(
      await coordinator.launch(profile),
      isA<LaunchBlockedAlreadyRunning>(),
    );
    expect(platform.launches, isEmpty);
  });

  test('a second launch never starts a second instance', () async {
    expect(await coordinator.launch(profile), isA<LaunchStarted>());
    expect(
      await coordinator.launch(profile),
      isA<LaunchBlockedAlreadyRunning>(),
    );
    expect(platform.launches, hasLength(1));
  });

  test('asks first when an ordinary Syrius install exists', () async {
    Directory(platform.defaultSdkRoot).createSync(recursive: true);

    expect(await coordinator.launch(profile), isA<LaunchNeedsFirstRunChoice>());
    expect(platform.launches, isEmpty);
    expect(
      await coordinator.launch(profile, firstRunConfirmed: true),
      isA<LaunchStarted>(),
    );
  });

  test('does not ask again once the profile has a wallet', () async {
    Directory(platform.defaultSdkRoot).createSync(recursive: true);
    final wallet = p.join(
      platform.sdkRootForHome(profiles.homeFor(profile.id)),
      'wallet',
    );
    Directory(wallet).createSync(recursive: true);
    File(p.join(wallet, 'wallet.json')).writeAsStringSync('{}');

    expect(await coordinator.launch(profile), isA<LaunchStarted>());
  });

  test('reports an early exit instead of success', () async {
    platform.exitImmediately = true;
    expect(await coordinator.launch(profile), isA<LaunchExitedEarly>());
  });

  test('reports a process start failure', () async {
    platform.launchError = const ProcessException('x', [], 'denied');
    final result = await coordinator.launch(profile);
    expect(result, isA<LaunchFailed>());
  });

  test('fails when the profile folder is missing', () async {
    Directory(profiles.homeFor(profile.id)).deleteSync();
    expect(await coordinator.launch(profile), isA<LaunchFailed>());
    expect(platform.launches, isEmpty);
  });

  group('WalletConnect', () {
    test('the shared-data notice is required once', () async {
      final fresh = ProfileService(
        repository: InMemoryProfileRepository(
          profiles.settings.copyWith(walletConnectNoticeAcknowledged: false),
        ),
        profilesRootPath: profiles.profilesRoot,
        trash: FakeTrash(temp),
      );
      await fresh.load();
      final freshCoordinator = LaunchCoordinator(
        platform: platform,
        profiles: fresh,
        earlyExitWindow: Duration.zero,
      );

      expect(
        await freshCoordinator.launch(profile),
        isA<LaunchNeedsWalletConnectNotice>(),
      );
      expect(platform.launches, isEmpty);

      await fresh.acknowledgeWalletConnectNotice();
      expect(await freshCoordinator.launch(profile), isA<LaunchStarted>());
    });

    test('data is kept by default', () async {
      platform.walletConnect = _connected;
      await coordinator.launch(profile);
      expect(platform.clearCalls, 0);
      expect(platform.walletConnect.sessions, 1);
    });

    test('clear-before-launch clears before starting Syrius', () async {
      platform.walletConnect = _connected;
      await profiles.setClearWalletConnectOnLaunch(true);

      expect(await coordinator.launch(profile), isA<LaunchStarted>());
      expect(platform.clearCalls, 1);
      expect(platform.walletConnect.hasConnections, isFalse);
    });

    test('a failed clear blocks the launch', () async {
      await profiles.setClearWalletConnectOnLaunch(true);
      platform.clearError = StateError('cfprefsd unavailable');

      expect(await coordinator.launch(profile), isA<LaunchFailed>());
      expect(platform.launches, isEmpty);
    });

    test('nothing is cleared while Syrius is running', () async {
      await profiles.setClearWalletConnectOnLaunch(true);
      platform.running = {1};

      expect(
        await coordinator.launch(profile),
        isA<LaunchBlockedAlreadyRunning>(),
      );
      expect(platform.clearCalls, 0);
    });
  });

  test('a saved pid is only trusted while it is still running', () async {
    await coordinator.launch(profile);

    expect(coordinator.verifiedRunningProfileId({4242}), profile.id);
    expect(coordinator.verifiedRunningProfileId({7}), isNull);
    expect(coordinator.verifiedRunningProfileId({}), isNull);
  });
}
