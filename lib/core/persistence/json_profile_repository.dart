import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/launcher_settings.dart';
import 'file_permissions.dart';
import 'profile_repository.dart';

/// Stores [LauncherSettings] as `profiles.json` in the launcher's own
/// application-support directory.
class JsonProfileRepository implements ProfileRepository {
  JsonProfileRepository(this.directory);

  /// Launcher metadata directory (from path_provider). Never a Syrius path.
  final Directory directory;

  File get file => File(p.join(directory.path, 'profiles.json'));

  @override
  Future<LauncherSettings> load() async {
    final source = file;
    if (!await source.exists()) return const LauncherSettings.empty();
    try {
      final text = await source.readAsString();
      return LauncherSettings.fromJson(jsonDecode(text));
    } on FormatException catch (error) {
      throw MetadataException(error.message);
    } on FileSystemException catch (error) {
      throw MetadataException('Could not read metadata: ${error.message}');
    }
  }

  @override
  Future<void> save(LauncherSettings settings) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      await restrictToOwner(directory.path, isDirectory: true);
    }
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(settings.toJson());
    // Round-trip before touching the real file, so a bug can never replace
    // good metadata with something we cannot read back.
    LauncherSettings.fromJson(jsonDecode(encoded));

    final temp = File('${file.path}.tmp');
    final handle = await temp.open(mode: FileMode.writeOnly);
    try {
      await handle.writeString(encoded);
      await handle.flush();
    } finally {
      await handle.close();
    }
    await restrictToOwner(temp.path, isDirectory: false);
    await temp.rename(file.path);
  }

  @override
  Future<String?> quarantine() async {
    final source = file;
    if (!await source.exists()) return null;
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backup = '${source.path}.invalid-$stamp';
    await source.rename(backup);
    return backup;
  }
}
