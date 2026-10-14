import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/launcher_settings.dart';
import '../models/wallet_profile.dart';
import '../persistence/file_permissions.dart';
import '../persistence/profile_repository.dart';

abstract interface class ProfileTrash {
  /// Moves [path] to the user's Trash and returns its new location.
  /// Throws [TrashException] on failure.
  Future<String?> moveToTrash(String path);
}

class TrashException implements Exception {
  const TrashException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A user-facing failure of a profile operation. Nothing was changed when
/// this is thrown, unless the message says otherwise.
class ProfileOperationException implements Exception {
  const ProfileOperationException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<bool> directoryHasEntries(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return false;
  return !(await dir.list(followLinks: false).isEmpty);
}

/// Owns the profile list, the selection and each profile's private HOME
/// directory (`<profilesRoot>/<uuid>`).
///
/// Directories are created only after an explicit Create, are named by
/// immutable UUIDs, and are only ever removed by moving them to the Trash.
class ProfileService {
  ProfileService({
    required this._repository,
    required String profilesRootPath,
    required this._trash,
    this._uuid = const Uuid(),
    this._clock = DateTime.now,
    this._restrictPermissions = restrictToOwner,
  }) : profilesRoot = p.normalize(p.absolute(profilesRootPath));

  final ProfileRepository _repository;
  final ProfileTrash _trash;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final PermissionRestrictor _restrictPermissions;

  /// Shared parent of all profile HOME directories. Created lazily.
  final String profilesRoot;

  LauncherSettings _settings = const LauncherSettings.empty();
  LauncherSettings get settings => _settings;
  List<WalletProfile> get profiles => _settings.profiles;

  /// Loads metadata. When stored metadata is unusable it is moved aside (never
  /// deleted) and the launcher starts empty; the backup path is returned so
  /// the UI can tell the user. Wallet directories are not touched.
  Future<String?> load() async {
    try {
      _settings = await _repository.load();
      return null;
    } on MetadataException {
      final backup = await _repository.quarantine();
      _settings = const LauncherSettings.empty();
      return backup;
    }
  }

  /// The private HOME for [profileId]. Throws [ProfileOperationException]
  /// unless the id is a UUID whose directory is directly inside
  /// [profilesRoot].
  String homeFor(String profileId) {
    if (!WalletProfile.isValidId(profileId)) {
      throw const ProfileOperationException('Invalid profile id.');
    }
    final home = p.normalize(p.join(profilesRoot, profileId));
    if (!p.isWithin(profilesRoot, home) || p.dirname(home) != profilesRoot) {
      throw const ProfileOperationException(
        'Profile folder is outside the managed profile root.',
      );
    }
    return home;
  }

  Future<WalletProfile> create({
    required String name,
    required String description,
    required ProfileIcon icon,
    bool select = true,
  }) async {
    final (cleanName, cleanDescription) = _validated(name, description);

    await _ensureProfilesRoot();
    var id = _uuid.v4();
    while (await FileSystemEntity.type(homeFor(id), followLinks: false) !=
        FileSystemEntityType.notFound) {
      id = _uuid.v4();
    }
    final home = Directory(homeFor(id));
    await home.create();

    final profile = WalletProfile(
      id: id,
      name: cleanName,
      description: cleanDescription,
      icon: icon,
      createdAt: _clock().toUtc(),
    );
    try {
      await _restrictPermissions(home.path, isDirectory: true);
      await _commit(
        _settings.copyWith(
          profiles: [..._settings.profiles, profile],
          selectedProfileId: select ? () => id : null,
        ),
      );
    } catch (_) {
      // Roll back: the directory was created moments ago and is still empty,
      // so a non-recursive delete is safe and cannot remove wallet data.
      try {
        await home.delete();
      } on FileSystemException {
        // Leave it; an empty orphan directory is harmless.
      }
      rethrow;
    }
    return profile;
  }

  /// Updates display metadata only. The id and directory never change.
  Future<WalletProfile> update(
    String id, {
    required String name,
    required String description,
    required ProfileIcon icon,
  }) async {
    final existing = _requireProfile(id);
    final (cleanName, cleanDescription) = _validated(name, description);
    final updated = existing.copyWith(
      name: cleanName,
      description: cleanDescription,
      icon: icon,
    );
    await _commit(
      _settings.copyWith(
        profiles: [
          for (final profile in _settings.profiles)
            profile.id == id ? updated : profile,
        ],
      ),
    );
    return updated;
  }

  /// Moves the profile's directory to the Trash, then removes its metadata.
  /// The caller must make sure the profile is not running.
  Future<void> remove(String id) async {
    _requireProfile(id);
    final home = homeFor(id);
    String? trashedAt;

    switch (await FileSystemEntity.type(home, followLinks: false)) {
      case FileSystemEntityType.notFound:
        break;
      case FileSystemEntityType.directory:
        if (await FileSystemEntity.isLink(profilesRoot)) {
          throw const ProfileOperationException(
            'The profile root is a symbolic link; refusing to move files.',
          );
        }
        try {
          trashedAt = await _trash.moveToTrash(home);
        } on TrashException catch (error) {
          throw ProfileOperationException(
            'The profile folder could not be moved to the Trash, so nothing '
            'was removed. ($error)',
          );
        }
      default:
        throw const ProfileOperationException(
          'The profile folder is not a regular directory; refusing to move it.',
        );
    }

    final index = _settings.profiles.indexWhere((profile) => profile.id == id);
    final remaining = [..._settings.profiles]..removeAt(index);
    String? nextSelection = _settings.selectedProfileId;
    if (nextSelection == id) {
      nextSelection = remaining.isEmpty
          ? null
          : remaining[index.clamp(0, remaining.length - 1)].id;
    }

    try {
      await _commit(
        _settings.copyWith(
          profiles: remaining,
          selectedProfileId: () => nextSelection,
        ),
      );
    } catch (_) {
      if (trashedAt != null) {
        try {
          await Directory(trashedAt).rename(home);
        } on FileSystemException {
          throw ProfileOperationException(
            'The profile folder was moved to the Trash but the profile list '
            'could not be updated. Restore it from: $trashedAt',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> select(String? id) async {
    if (id != null) _requireProfile(id);
    if (id == _settings.selectedProfileId) return;
    await _commit(_settings.copyWith(selectedProfileId: () => id));
  }

  Future<void> setSyriusAppPath(String? path) async {
    if (path == _settings.syriusAppPath) return;
    await _commit(_settings.copyWith(syriusAppPath: () => path));
  }

  Future<void> setLastLaunch(LastLaunchRecord? record) =>
      _commit(_settings.copyWith(lastLaunch: () => record));

  Future<void> _commit(LauncherSettings next) async {
    final normalized = next.normalized();
    await _repository.save(normalized);
    _settings = normalized;
  }

  WalletProfile _requireProfile(String id) {
    final profile = _settings.profileById(id);
    if (profile == null) {
      throw const ProfileOperationException('That profile no longer exists.');
    }
    return profile;
  }

  (String, String) _validated(String name, String description) {
    final error =
        WalletProfile.validateName(name) ??
        WalletProfile.validateDescription(description);
    if (error != null) throw ProfileOperationException(error);
    return (name.trim(), description.trim());
  }

  Future<void> _ensureProfilesRoot() async {
    switch (await FileSystemEntity.type(profilesRoot, followLinks: false)) {
      case FileSystemEntityType.directory:
        return;
      case FileSystemEntityType.notFound:
        await Directory(profilesRoot).create(recursive: true);
        await _restrictPermissions(profilesRoot, isDirectory: true);
      default:
        throw ProfileOperationException(
          '$profilesRoot exists but is not a regular folder.',
        );
    }
  }
}
