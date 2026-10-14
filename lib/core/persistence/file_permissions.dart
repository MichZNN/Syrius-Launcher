import 'dart:io';

typedef PermissionRestrictor = Future<void> Function(
  String path, {
  required bool isDirectory,
});

/// Restricts [path] to the current user (0700 for directories, 0600 for
/// files). dart:io has no chmod, so this runs `/bin/chmod` directly with an
/// argument list (no shell). No-op on Windows.
Future<void> restrictToOwner(String path, {required bool isDirectory}) async {
  if (Platform.isWindows) return;
  final result = await Process.run('/bin/chmod', [
    isDirectory ? '700' : '600',
    path,
  ]);
  if (result.exitCode != 0) {
    throw FileSystemException('Could not restrict permissions', path);
  }
}
