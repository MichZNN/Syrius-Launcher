import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:syrius_launcher/core/services/syrius_locator.dart';

import 'support/fakes.dart';

void main() {
  late Directory temp;
  late FakeBundleInspector inspector;
  late SyriusLocator locator;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('launcher_locator_');
    inspector = FakeBundleInspector();
    locator = SyriusLocator(inspector: inspector, homeDirectory: temp.path);
  });

  tearDown(() => temp.delete(recursive: true));

  /// Creates a minimal fake bundle with an executable named like Syrius.
  String makeBundle(
    String name, {
    String bundleId = SyriusLocator.bundleIdentifier,
    String executable = 's y r i u s',
    bool executableBit = true,
  }) {
    final app = p.join(temp.path, name);
    final macOs = Directory(p.join(app, 'Contents', 'MacOS'))
      ..createSync(recursive: true);
    final binary = File(p.join(macOs.path, executable))
      ..writeAsStringSync('#!/bin/sh\n');
    if (executableBit) Process.runSync('/bin/chmod', ['755', binary.path]);
    inspector.bundles[app] = BundleInfo(
      bundleIdentifier: bundleId,
      executableName: executable,
      shortVersion: 'v0.2.4-alphanet',
    );
    return app;
  }

  test(
    'resolves the executable from CFBundleExecutable, spaces included',
    () async {
      final app = makeBundle('s y r i u s.app');

      final installation = await locator.validate(app);

      expect(installation.appPath, app);
      expect(installation.executableName, 's y r i u s');
      expect(
        installation.executablePath,
        p.join(app, 'Contents', 'MacOS', 's y r i u s'),
      );
      expect(installation.version, 'v0.2.4-alphanet');
    },
  );

  test('rejects a different bundle identifier', () async {
    final app = makeBundle('Other.app', bundleId: 'com.example.other');
    await expectLater(
      locator.validate(app),
      throwsA(isA<SyriusInstallationException>()),
    );
  });

  test('rejects non-executable, missing and escaping executables', () async {
    final notExec = makeBundle('a.app', executableBit: false);
    final escaping = makeBundle('b.app');
    inspector.bundles[escaping] = const BundleInfo(
      bundleIdentifier: SyriusLocator.bundleIdentifier,
      executableName: '../../evil',
    );
    final missing = makeBundle('c.app');
    File(p.join(missing, 'Contents', 'MacOS', 's y r i u s')).deleteSync();

    for (final app in [notExec, escaping, missing]) {
      await expectLater(
        locator.validate(app),
        throwsA(isA<SyriusInstallationException>()),
        reason: app,
      );
    }
  });

  test('rejects a symlinked executable', () async {
    final app = makeBundle('s.app');
    final binary = p.join(app, 'Contents', 'MacOS', 's y r i u s');
    File(binary).renameSync(p.join(temp.path, 'real'));
    Link(binary).createSync(p.join(temp.path, 'real'));

    await expectLater(
      locator.validate(app),
      throwsA(isA<SyriusInstallationException>()),
    );
  });

  test('rejects paths that are not .app bundles', () async {
    await expectLater(
      locator.validate(temp.path),
      throwsA(isA<SyriusInstallationException>()),
    );
  });

  test(
    'discover prefers the saved path and skips invalid candidates',
    () async {
      final invalid = makeBundle('broken.app', bundleId: 'x');
      final saved = makeBundle('saved.app');
      final other = makeBundle('other.app');

      expect(
        (await locator.discover(
          savedPath: saved,
          launchServicesPaths: [other],
        ))?.appPath,
        saved,
      );
      expect(
        (await locator.discover(
          savedPath: invalid,
          launchServicesPaths: [other],
        ))?.appPath,
        other,
      );
    },
  );

  test('discover finds ~/Applications/s y r i u s.app', () async {
    final app = makeBundle(p.join('Applications', 's y r i u s.app'));
    expect((await locator.discover())?.appPath, app);
  });
}
