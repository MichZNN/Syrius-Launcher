import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:syrius_launcher/app.dart';
import 'package:syrius_launcher/core/models/launcher_settings.dart';
import 'package:syrius_launcher/core/models/wallet_profile.dart';
import 'package:syrius_launcher/core/models/walletconnect_summary.dart';
import 'package:syrius_launcher/core/services/launch_coordinator.dart';
import 'package:syrius_launcher/core/services/process_monitor.dart';
import 'package:syrius_launcher/core/services/profile_service.dart';
import 'package:syrius_launcher/core/theme/launcher_palette.dart';
import 'package:syrius_launcher/features/home/launcher_controller.dart';
import 'package:syrius_launcher/features/home/walletconnect_dialogs.dart';

import 'support/fakes.dart';

/// Test harness around the real controller and services, with an in-memory
/// repository and a fake platform. Profile folders go to a temp directory.
class _Harness {
  _Harness._(this.temp, this.repository, this.platform, this.controller);

  final Directory temp;
  final InMemoryProfileRepository repository;
  final FakePlatformLauncher platform;
  final LauncherController controller;

  static Future<_Harness> create(
    WidgetTester tester, {
    LauncherSettings? stored,
  }) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('launcher_widget_'),
    ))!;
    final trashDir = Directory(p.join(temp.path, 'trash'))..createSync();
    final repository = InMemoryProfileRepository(
      stored ??
          const LauncherSettings.empty().copyWith(
            walletConnectNoticeAcknowledged: true,
          ),
    );
    final platform = FakePlatformLauncher(home: p.join(temp.path, 'home'));
    final profiles = ProfileService(
      repository: repository,
      profilesRootPath: p.join(temp.path, 'SyriusProfiles'),
      trash: FakeTrash(trashDir),
      // chmod runs as a subprocess, which never completes inside the widget
      // test's fake-async zone; permissions are covered by unit tests.
      restrictPermissions: (_, {required isDirectory}) async {},
    );
    final controller = LauncherController(
      profiles: profiles,
      platform: platform,
      coordinator: LaunchCoordinator(
        platform: platform,
        profiles: profiles,
        earlyExitWindow: Duration.zero,
      ),
      monitor: ProcessMonitor(platform: platform),
    );

    tester.view.physicalSize = const Size(480, 532);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      SyriusLauncherApp(controller: controller, showPlatformMenus: false),
    );
    await controller.initialize();
    await tester.pumpAndSettle();
    return _Harness._(temp, repository, platform, controller);
  }

  /// Lets real file-system work finish, then settles the UI.
  Future<void> settle(WidgetTester tester) async {
    // Every awaited file-system call needs its own real-time slice.
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    controller.dispose();
    tester.view.reset();
    await tester.runAsync(() => temp.delete(recursive: true));
  }

  Future<void> addProfile(
    WidgetTester tester,
    String name, {
    String description = '',
    String? iconLabel,
  }) async {
    await tester.tap(find.text('Add wallet profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Profile name'),
      name,
    );
    if (description.isNotEmpty) {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        description,
      );
    }
    if (iconLabel != null) {
      await tester.tap(find.byTooltip(iconLabel));
    }
    await tester.tap(find.text('Create'));
    await settle(tester);
  }
}

Finder _launchButton() => find.ancestor(
  of: find.text('Launch Syrius'),
  matching: find.byType(FilledButton),
);

bool _launchEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_launchButton()).onPressed != null;

Finder _tileOf(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byType(AnimatedContainer),
);

void main() {
  testWidgets('fresh install shows the empty state and no profile cards', (
    tester,
  ) async {
    final h = await _Harness.create(tester);

    expect(find.text('Syrius Launcher'), findsOneWidget);
    expect(find.text('Select your wallet profile'), findsOneWidget);
    expect(find.text('No wallet profiles yet'), findsOneWidget);
    expect(find.text('Create a profile to get started'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    for (final seeded in ['Main Wallet', 'Pillar Wallet', 'Sentinel Wallet']) {
      expect(find.text(seeded), findsNothing);
    }
    expect(_launchEnabled(tester), isFalse);
    expect(find.text('Add wallet profile'), findsOneWidget);
    expect(h.controller.selectedProfileId, isNull);
    expect(h.repository.saveCount, 0);
    expect(
      Directory(p.join(h.temp.path, 'SyriusProfiles')).existsSync(),
      false,
    );

    await h.dispose(tester);
  });

  testWidgets('cancel in the Add dialog creates nothing', (tester) async {
    final h = await _Harness.create(tester);

    await tester.tap(find.text('Add wallet profile'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      isEmpty,
    );
    await tester.tap(find.text('Cancel'));
    await h.settle(tester);

    expect(find.text('No wallet profiles yet'), findsOneWidget);
    expect(h.repository.saveCount, 0);
    expect(
      Directory(p.join(h.temp.path, 'SyriusProfiles')).existsSync(),
      false,
    );

    await h.dispose(tester);
  });

  testWidgets('an empty name is rejected in the dialog', (tester) async {
    final h = await _Harness.create(tester);

    await tester.tap(find.text('Add wallet profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a profile name.'), findsOneWidget);
    expect(h.repository.saveCount, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await h.dispose(tester);
  });

  testWidgets('creating profiles renders the user data and moves Active', (
    tester,
  ) async {
    final h = await _Harness.create(tester);

    await h.addProfile(tester, 'Mijn wallet', description: 'Dagelijks');
    expect(find.text('Mijn wallet'), findsOneWidget);
    expect(find.text('Dagelijks'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(_launchEnabled(tester), isTrue);

    await h.addProfile(tester, 'Node', iconLabel: 'Server');
    expect(find.byIcon(Icons.dns_outlined), findsOneWidget);
    // The newly created profile is selected.
    expect(
      find.descendant(of: _tileOf('Node'), matching: find.text('Active')),
      findsOneWidget,
    );

    await tester.tap(find.text('Mijn wallet'));
    await h.settle(tester);
    expect(
      find.descendant(
        of: _tileOf('Mijn wallet'),
        matching: find.text('Active'),
      ),
      findsOneWidget,
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Node'), findsOneWidget);
    expect(find.text('Dagelijks'), findsOneWidget);

    await h.dispose(tester);
  });

  testWidgets('edit via right-click changes the card; cancel does not', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    await h.addProfile(tester, 'Before', description: 'old');
    final id = h.controller.profiles.single.id;

    await tester.tap(find.text('Before'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Profile name'),
      'Changed',
    );
    await tester.tap(find.text('Cancel'));
    await h.settle(tester);
    expect(find.text('Before'), findsOneWidget);

    await tester.tap(find.text('Before'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Profile name'),
      'After',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description (optional)'),
      '',
    );
    await tester.tap(find.byTooltip('Shield'));
    await tester.tap(find.text('Save'));
    await h.settle(tester);

    expect(find.text('After'), findsOneWidget);
    expect(find.text('old'), findsNothing);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    expect(h.controller.profiles.single.id, id);

    await h.dispose(tester);
  });

  testWidgets('keyboard: Tab focuses a card, Enter selects, menu key opens', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    await h.addProfile(tester, 'First');
    await h.addProfile(tester, 'Second');
    expect(h.controller.selectedProfile?.name, 'Second');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await h.settle(tester);
    expect(h.controller.selectedProfile?.name, 'First');

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Remove profile'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await h.dispose(tester);
  });

  testWidgets('removing the last profile returns to the empty state', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    await h.addProfile(tester, 'Temporary');

    await tester.tap(find.text('Temporary'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove profile'));
    await h.settle(tester);
    expect(find.textContaining('moved to the Trash'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove profile'));
    await h.settle(tester);

    expect(find.text('No wallet profiles yet'), findsOneWidget);
    expect(h.controller.selectedProfileId, isNull);
    expect(_launchEnabled(tester), isFalse);

    await h.dispose(tester);
  });

  testWidgets('many profiles scroll while the button stays visible', (
    tester,
  ) async {
    final profiles = [
      for (var i = 0; i < 12; i++)
        WalletProfile(
          id: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          name: 'Profile $i',
          description: '',
          icon: ProfileIcon.wallet,
          createdAt: DateTime.utc(2026),
        ),
    ];
    final h = await _Harness.create(
      tester,
      stored: LauncherSettings(
        profiles: profiles,
        selectedProfileId: profiles.first.id,
        syriusAppPath: null,
      ),
    );

    expect(find.text('Profile 0'), findsOneWidget);
    expect(find.text('Profile 11'), findsNothing);
    final screen = tester.getRect(find.byType(Scaffold));
    expect(screen.contains(tester.getCenter(_launchButton())), isTrue);

    await tester.scrollUntilVisible(find.text('Profile 11'), 200);
    expect(find.text('Profile 11'), findsOneWidget);
    expect(screen.contains(tester.getCenter(_launchButton())), isTrue);
    expect(find.text('Add wallet profile'), findsOneWidget);

    await h.dispose(tester);
  });

  testWidgets('launch blocked while Syrius runs shows the conflict message', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    await h.addProfile(tester, 'Wallet');
    h.platform.running = {123};

    await tester.tap(_launchButton());
    await h.settle(tester);

    expect(find.textContaining('Syrius is already running'), findsOneWidget);
    expect(h.platform.launches, isEmpty);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await h.dispose(tester);
  });

  testWidgets('launch starts Syrius for the selected profile', (tester) async {
    final h = await _Harness.create(tester);
    await h.addProfile(tester, 'Wallet');

    await tester.tap(_launchButton());
    await h.settle(tester);

    expect(
      h.platform.launches.single.profileId,
      h.controller.selectedProfileId,
    );
    expect(h.controller.runningProfileId, h.controller.selectedProfileId);
    expect(find.text('Launch Syrius'), findsOneWidget);

    await h.dispose(tester);
  });

  testWidgets('first launch shows the WalletConnect notice once', (
    tester,
  ) async {
    final h = await _Harness.create(
      tester,
      stored: const LauncherSettings.empty(),
    );
    await h.addProfile(tester, 'Wallet');

    await tester.tap(_launchButton());
    await h.settle(tester);
    expect(find.text('WalletConnect is shared'), findsOneWidget);
    expect(h.platform.launches, isEmpty);

    await tester.tap(find.text('I understand'));
    await h.settle(tester);
    expect(h.platform.launches, hasLength(1));
    expect(h.repository.stored!.walletConnectNoticeAcknowledged, isTrue);

    await h.dispose(tester);
  });

  testWidgets('WalletConnect dialog clears data and saves the option', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    h.platform.walletConnect = const WalletConnectSummary(
      sessions: 2,
      pairings: 1,
      storageKeys: 28,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showWalletConnectDialog(context, controller: h.controller),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settle(tester);
    expect(
      find.text('Stored connections: 2 sessions, 1 pairing.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await h.settle(tester);
    expect(h.repository.stored!.clearWalletConnectOnLaunch, isTrue);

    await tester.tap(find.text('Clear WalletConnect data now...'));
    await h.settle(tester);
    await tester.tap(find.text('Clear'));
    await h.settle(tester);
    await tester.ensureVisible(find.text('WalletConnect data cleared.'));
    expect(find.text('WalletConnect data cleared.'), findsOneWidget);
    expect(find.text('No dApps are connected.'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await h.dispose(tester);
  });

  testWidgets('WalletConnect cannot be cleared while Syrius runs', (
    tester,
  ) async {
    final h = await _Harness.create(tester);
    h.platform.running = {5};
    await h.controller.initialize();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showWalletConnectDialog(context, controller: h.controller),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settle(tester);

    final clear = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Clear WalletConnect data now...'),
    );
    expect(clear.onPressed, isNull);
    expect(h.platform.clearCalls, 0);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await h.dispose(tester);
  });

  // Goldens depend on the machine's rendering, so CI skips them with
  // `--exclude-tags golden`; regenerate locally with --update-goldens.
  group('goldens', () {
    testWidgets('empty home', tags: 'golden', (tester) async {
      final h = await _Harness.create(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_empty.png'),
      );
      await h.dispose(tester);
    });

    testWidgets('populated home', tags: 'golden', (tester) async {
      final h = await _Harness.create(tester);
      await h.addProfile(tester, 'My Wallet', description: 'Everyday wallet');
      await h.addProfile(tester, 'Pillar node', iconLabel: 'Server');
      await tester.tap(find.text('My Wallet'));
      await h.settle(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_populated.png'),
      );
      expect(
        tester.widget<AnimatedContainer>(_tileOf('Pillar node')).decoration,
        isA<BoxDecoration>().having(
          (d) => d.color,
          'color',
          LauncherPalette.profileBackground,
        ),
      );
      await h.dispose(tester);
    });
  });
}
