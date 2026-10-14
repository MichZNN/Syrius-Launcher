import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:syrius_launcher/core/models/launcher_settings.dart';
import 'package:syrius_launcher/core/models/wallet_profile.dart';
import 'package:syrius_launcher/core/persistence/json_profile_repository.dart';
import 'package:syrius_launcher/core/persistence/profile_repository.dart';

const _idA = '7e3db53e-2a08-4c53-a418-e7b3abdc1a64';
const _idB = '0b6c1f8e-3f0a-4a51-9d5e-2c1c7c9f0a11';

WalletProfile _profile(String id, String name) => WalletProfile(
  id: id,
  name: name,
  description: '',
  icon: ProfileIcon.wallet,
  createdAt: DateTime.utc(2026, 10, 14),
);

void main() {
  late Directory temp;
  late JsonProfileRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('launcher_repo_');
    repository = JsonProfileRepository(Directory(p.join(temp.path, 'meta')));
  });

  tearDown(() => temp.delete(recursive: true));

  test('missing metadata loads empty without writing anything', () async {
    final settings = await repository.load();

    expect(settings.profiles, isEmpty);
    expect(settings.selectedProfileId, isNull);
    expect(settings.syriusAppPath, isNull);
    expect(await repository.directory.exists(), isFalse);
  });

  test('round-trips profiles, selection and app path', () async {
    final settings = LauncherSettings(
      profiles: [_profile(_idA, 'Mijn wallet ✓'), _profile(_idB, 'Second')],
      selectedProfileId: _idB,
      syriusAppPath: '/Applications/s y r i u s.app',
    );
    await repository.save(settings);
    final loaded = await repository.load();

    expect(loaded.profiles, settings.profiles);
    expect(loaded.selectedProfileId, _idB);
    expect(loaded.syriusAppPath, '/Applications/s y r i u s.app');
  });

  test('WalletConnect options round-trip and default to off', () async {
    await repository.save(const LauncherSettings.empty());
    var loaded = await repository.load();
    expect(loaded.clearWalletConnectOnLaunch, isFalse);
    expect(loaded.walletConnectNoticeAcknowledged, isFalse);

    await repository.save(
      loaded.copyWith(
        clearWalletConnectOnLaunch: true,
        walletConnectNoticeAcknowledged: true,
      ),
    );
    loaded = await repository.load();
    expect(loaded.clearWalletConnectOnLaunch, isTrue);
    expect(loaded.walletConnectNoticeAcknowledged, isTrue);
  });

  test(
    'writes atomically with a schema version and private permissions',
    () async {
      await repository.save(
        LauncherSettings(
          profiles: [_profile(_idA, 'A')],
          selectedProfileId: _idA,
          syriusAppPath: null,
        ),
      );

      final json = jsonDecode(await repository.file.readAsString()) as Map;
      expect(json['schemaVersion'], 1);
      expect(File('${repository.file.path}.tmp').existsSync(), isFalse);
      expect(repository.file.statSync().mode & 0x1FF, 0x180); // 0600
      expect(repository.directory.statSync().mode & 0x1FF, 0x1C0); // 0700
    },
  );

  test('never stores secret-looking fields', () async {
    await repository.save(
      LauncherSettings(
        profiles: [_profile(_idA, 'A')],
        selectedProfileId: _idA,
        syriusAppPath: null,
      ),
    );
    final text = (await repository.file.readAsString()).toLowerCase();
    for (final word in ['mnemonic', 'seed', 'password', 'private']) {
      expect(text, isNot(contains(word)));
    }
  });

  test('a selection that points to a missing profile becomes null', () async {
    await repository.directory.create(recursive: true);
    await repository.file.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'selectedProfileId': _idB,
        'syriusAppPath': null,
        'profiles': [_profile(_idA, 'A').toJson()],
      }),
    );

    final loaded = await repository.load();
    expect(loaded.profiles.single.id, _idA);
    expect(loaded.selectedProfileId, isNull);
  });

  test('malformed or unsupported metadata throws MetadataException', () async {
    await repository.directory.create(recursive: true);
    for (final content in [
      '{not json',
      '{"schemaVersion": 2, "profiles": []}',
      '{"schemaVersion": 1, "profiles": [{"id": "../../etc", "name": "x"}]}',
    ]) {
      await repository.file.writeAsString(content);
      await expectLater(repository.load(), throwsA(isA<MetadataException>()));
    }
  });

  test('quarantine moves unreadable metadata aside', () async {
    await repository.directory.create(recursive: true);
    await repository.file.writeAsString('{not json');

    final backup = await repository.quarantine();

    expect(backup, isNotNull);
    expect(File(backup!).readAsStringSync(), '{not json');
    expect(repository.file.existsSync(), isFalse);
    expect((await repository.load()).profiles, isEmpty);
  });
}
