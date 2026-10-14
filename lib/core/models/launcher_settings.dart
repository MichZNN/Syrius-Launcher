import 'package:flutter/foundation.dart';

import 'wallet_profile.dart';

/// The last Syrius process this launcher started. Treated as an untrusted
/// hint after a restart: the pid is only trusted again when it still belongs
/// to a running Syrius process.
@immutable
class LastLaunchRecord {
  const LastLaunchRecord({required this.profileId, required this.pid});

  final String profileId;
  final int pid;

  Map<String, Object?> toJson() => {'profileId': profileId, 'pid': pid};

  static LastLaunchRecord? tryParse(Object? json) {
    if (json is! Map) return null;
    final profileId = json['profileId'];
    final pid = json['pid'];
    if (profileId is! String || pid is! int || pid <= 0) return null;
    return LastLaunchRecord(profileId: profileId, pid: pid);
  }
}

/// Everything the launcher persists in `profiles.json`.
@immutable
class LauncherSettings {
  const LauncherSettings({
    required this.profiles,
    required this.selectedProfileId,
    required this.syriusAppPath,
    this.lastLaunch,
    this.clearWalletConnectOnLaunch = false,
    this.walletConnectNoticeAcknowledged = false,
  });

  /// First-launch state: zero profiles, nothing selected.
  const LauncherSettings.empty()
    : profiles = const [],
      selectedProfileId = null,
      syriusAppPath = null,
      lastLaunch = null,
      clearWalletConnectOnLaunch = false,
      walletConnectNoticeAcknowledged = false;

  static const schemaVersion = 1;

  final List<WalletProfile> profiles;
  final String? selectedProfileId;
  final String? syriusAppPath;
  final LastLaunchRecord? lastLaunch;

  /// Clear Syrius's WalletConnect state (which macOS shares between all
  /// profiles) before every launch. Off by default.
  final bool clearWalletConnectOnLaunch;

  /// The user has seen the "WalletConnect data is shared" warning.
  final bool walletConnectNoticeAcknowledged;

  WalletProfile? profileById(String? id) {
    if (id == null) return null;
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  LauncherSettings copyWith({
    List<WalletProfile>? profiles,
    ValueGetter<String?>? selectedProfileId,
    ValueGetter<String?>? syriusAppPath,
    ValueGetter<LastLaunchRecord?>? lastLaunch,
    bool? clearWalletConnectOnLaunch,
    bool? walletConnectNoticeAcknowledged,
  }) {
    return LauncherSettings(
      profiles: profiles ?? this.profiles,
      selectedProfileId: selectedProfileId != null
          ? selectedProfileId()
          : this.selectedProfileId,
      syriusAppPath: syriusAppPath != null
          ? syriusAppPath()
          : this.syriusAppPath,
      lastLaunch: lastLaunch != null ? lastLaunch() : this.lastLaunch,
      clearWalletConnectOnLaunch:
          clearWalletConnectOnLaunch ?? this.clearWalletConnectOnLaunch,
      walletConnectNoticeAcknowledged:
          walletConnectNoticeAcknowledged ??
          this.walletConnectNoticeAcknowledged,
    );
  }

  /// Drops references to profiles that no longer exist. Never invents a
  /// replacement profile.
  LauncherSettings normalized() {
    final seen = <String>{};
    final unique = [
      for (final profile in profiles)
        if (seen.add(profile.id)) profile,
    ];
    return LauncherSettings(
      profiles: List.unmodifiable(unique),
      selectedProfileId: seen.contains(selectedProfileId)
          ? selectedProfileId
          : null,
      syriusAppPath: syriusAppPath,
      lastLaunch: seen.contains(lastLaunch?.profileId) ? lastLaunch : null,
      clearWalletConnectOnLaunch: clearWalletConnectOnLaunch,
      walletConnectNoticeAcknowledged: walletConnectNoticeAcknowledged,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'selectedProfileId': selectedProfileId,
    'syriusAppPath': syriusAppPath,
    'profiles': [for (final profile in profiles) profile.toJson()],
    if (lastLaunch != null) 'lastLaunch': lastLaunch!.toJson(),
    'clearWalletConnectOnLaunch': clearWalletConnectOnLaunch,
    'walletConnectNoticeAcknowledged': walletConnectNoticeAcknowledged,
  };

  /// Throws [FormatException] when the document is not a valid v1 document.
  factory LauncherSettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Metadata root is not an object');
    }
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException('Unsupported schemaVersion: $version');
    }
    final rawProfiles = json['profiles'];
    if (rawProfiles is! List) {
      throw const FormatException('"profiles" is not a list');
    }
    final profiles = [
      for (final raw in rawProfiles)
        if (raw is Map<String, Object?>)
          WalletProfile.fromJson(raw)
        else
          throw const FormatException('Profile entry is not an object'),
    ];
    final selected = json['selectedProfileId'];
    final appPath = json['syriusAppPath'];
    return LauncherSettings(
      profiles: profiles,
      selectedProfileId: selected is String ? selected : null,
      syriusAppPath: appPath is String && appPath.isNotEmpty ? appPath : null,
      lastLaunch: LastLaunchRecord.tryParse(json['lastLaunch']),
      clearWalletConnectOnLaunch: json['clearWalletConnectOnLaunch'] == true,
      walletConnectNoticeAcknowledged:
          json['walletConnectNoticeAcknowledged'] == true,
    ).normalized();
  }
}
