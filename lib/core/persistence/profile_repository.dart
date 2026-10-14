import '../models/launcher_settings.dart';

/// Thrown when stored metadata exists but cannot be used (malformed JSON,
/// unsupported schema). Wallet data is never touched in that case.
class MetadataException implements Exception {
  const MetadataException(this.message);
  final String message;

  @override
  String toString() => 'MetadataException: $message';
}

/// Persistence for the launcher's own non-secret metadata.
///
/// Settings are stored as a single document so that related changes (for
/// example "add profile and select it") are committed in one atomic write.
abstract interface class ProfileRepository {
  /// Returns [LauncherSettings.empty] when nothing has been stored yet.
  /// Throws [MetadataException] when stored data is unusable.
  Future<LauncherSettings> load();

  Future<void> save(LauncherSettings settings);

  /// Moves unusable metadata aside so it can be inspected later, and returns
  /// the backup path (or null when there was nothing to move).
  Future<String?> quarantine();
}
