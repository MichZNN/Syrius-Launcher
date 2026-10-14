import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:syrius_launcher/core/models/wallet_profile.dart';
import 'package:syrius_launcher/core/services/profile_service.dart';

import 'support/fakes.dart';

void main() {
  late Directory temp;
  late String root;
  late InMemoryProfileRepository repository;
  late FakeTrash trash;
  late ProfileService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('launcher_service_');
    root = p.join(temp.path, 'Syrius Profiles'); // includes a space on purpose
    repository = InMemoryProfileRepository();
    trash = FakeTrash(await Directory(p.join(temp.path, 'trash')).create());
    service = ProfileService(
      repository: repository,
      profilesRootPath: root,
      trash: trash,
    );
  });

  tearDown(() => temp.delete(recursive: true));

  Future<WalletProfile> create(String name, {String description = ''}) =>
      service.create(
        name: name,
        description: description,
        icon: ProfileIcon.wallet,
      );

  test('first load has zero profiles and creates no directories', () async {
    await service.load();

    expect(service.profiles, isEmpty);
    expect(service.settings.selectedProfileId, isNull);
    expect(Directory(root).existsSync(), isFalse);
    expect(repository.saveCount, 0);
  });

  test('create makes a private UUID folder and selects the profile', () async {
    await service.load();
    final profile = await create('  Mijn wallet  ', description: ' cold ');

    expect(WalletProfile.isValidId(profile.id), isTrue);
    expect(profile.name, 'Mijn wallet');
    expect(profile.description, 'cold');
    expect(service.settings.selectedProfileId, profile.id);

    final home = Directory(service.homeFor(profile.id));
    expect(home.existsSync(), isTrue);
    expect(p.dirname(home.path), p.normalize(root));
    expect(home.statSync().mode & 0x1FF, 0x1C0); // 0700
    expect(Directory(root).statSync().mode & 0x1FF, 0x1C0);
    expect(repository.stored!.profiles.single, profile);
  });

  test('duplicate names are allowed but ids are unique', () async {
    final a = await create('Same');
    final b = await create('Same');

    expect(a.id, isNot(b.id));
    expect(service.profiles.map((profile) => profile.id), [a.id, b.id]);
    expect(service.settings.selectedProfileId, b.id);
  });

  test('create can add without changing the selection', () async {
    final a = await create('A');
    await service.create(
      name: 'B',
      description: '',
      icon: ProfileIcon.key,
      select: false,
    );
    expect(service.settings.selectedProfileId, a.id);
  });

  test('invalid input creates nothing', () async {
    await expectLater(create('   '), throwsA(isA<ProfileOperationException>()));
    await expectLater(
      create('x' * 49),
      throwsA(isA<ProfileOperationException>()),
    );
    await expectLater(
      create('ok', description: 'd' * 81),
      throwsA(isA<ProfileOperationException>()),
    );
    expect(service.profiles, isEmpty);
    expect(Directory(root).existsSync(), isFalse);
  });

  test('a failed metadata write rolls back the new folder', () async {
    repository.failNextSave = true;

    await expectLater(create('A'), throwsA(isA<FileSystemException>()));

    expect(service.profiles, isEmpty);
    expect(Directory(root).listSync(), isEmpty);
  });

  test('edit changes display data only', () async {
    final original = await create('Old', description: 'old desc');
    final home = service.homeFor(original.id);
    File(p.join(home, 'marker')).writeAsStringSync('keep');

    final updated = await service.update(
      original.id,
      name: 'New',
      description: '',
      icon: ProfileIcon.shield,
    );

    expect(updated.id, original.id);
    expect(updated.name, 'New');
    expect(updated.description, '');
    expect(updated.icon, ProfileIcon.shield);
    expect(updated.createdAt, original.createdAt);
    expect(service.homeFor(updated.id), home);
    expect(File(p.join(home, 'marker')).readAsStringSync(), 'keep');
  });

  test(
    'remove moves the folder to the Trash and selects a neighbour',
    () async {
      final a = await create('A');
      final b = await create('B');
      final c = await create('C');
      await service.select(b.id);
      final bHome = service.homeFor(b.id);

      await service.remove(b.id);

      expect(trash.trashed, [bHome]);
      expect(Directory(bHome).existsSync(), isFalse);
      expect(service.profiles.map((profile) => profile.id), [a.id, c.id]);
      expect(service.settings.selectedProfileId, c.id);
    },
  );

  test('removing the last profile returns to the empty state', () async {
    final only = await create('Only');

    await service.remove(only.id);

    expect(service.profiles, isEmpty);
    expect(service.settings.selectedProfileId, isNull);
  });

  test('if the Trash fails nothing is removed', () async {
    final a = await create('A');
    trash.fail = true;

    await expectLater(
      service.remove(a.id),
      throwsA(isA<ProfileOperationException>()),
    );
    expect(service.profiles.single.id, a.id);
    expect(Directory(service.homeFor(a.id)).existsSync(), isTrue);
  });

  test('a failed metadata write after trashing restores the folder', () async {
    final a = await create('A');
    final home = service.homeFor(a.id);
    repository.failNextSave = true;

    await expectLater(
      service.remove(a.id),
      throwsA(isA<FileSystemException>()),
    );

    expect(Directory(home).existsSync(), isTrue);
    expect(service.profiles.single.id, a.id);
  });

  test('refuses to trash a profile folder that is a symlink', () async {
    final a = await create('A');
    final home = service.homeFor(a.id);
    final elsewhere = await Directory(p.join(temp.path, 'elsewhere')).create();
    await Directory(home).delete();
    await Link(home).create(elsewhere.path);

    await expectLater(
      service.remove(a.id),
      throwsA(isA<ProfileOperationException>()),
    );
    expect(trash.trashed, isEmpty);
    expect(elsewhere.existsSync(), isTrue);
  });

  test('homeFor rejects anything that is not a UUID inside the root', () {
    for (final id in ['..', '../x', '/etc', 'abc', '']) {
      expect(
        () => service.homeFor(id),
        throwsA(isA<ProfileOperationException>()),
      );
    }
  });

  test(
    'unreadable metadata is quarantined and the launcher starts empty',
    () async {
      repository.corrupt = true;

      final backup = await service.load();

      expect(backup, isNotNull);
      expect(repository.quarantined, isTrue);
      expect(service.profiles, isEmpty);
    },
  );
}
