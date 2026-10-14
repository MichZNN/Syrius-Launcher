import 'package:flutter/material.dart';

/// Icon choices for a user-created profile. The [id] is what gets persisted;
/// [label] is shown in the Add/Edit dialogs.
enum ProfileIcon {
  wallet('wallet', 'Wallet', Icons.account_balance_wallet_outlined),
  server('server', 'Server', Icons.dns_outlined),
  shield('shield', 'Shield', Icons.verified_user_outlined),
  key('key', 'Key', Icons.key_outlined),
  savings('savings', 'Savings', Icons.savings_outlined);

  const ProfileIcon(this.id, this.label, this.iconData);

  final String id;
  final String label;
  final IconData iconData;

  /// Default *icon selection* in the Add dialog. This never creates a
  /// profile by itself.
  static const defaultChoice = ProfileIcon.wallet;

  /// Unknown ids (e.g. written by a newer launcher) fall back to the wallet
  /// icon for display only.
  static ProfileIcon fromId(String? id) => ProfileIcon.values.firstWhere(
    (icon) => icon.id == id,
    orElse: () => ProfileIcon.wallet,
  );
}

/// Launcher-owned, non-secret display metadata for one wallet profile.
///
/// There is intentionally no field for mnemonics, keys or passwords.
@immutable
class WalletProfile {
  const WalletProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.createdAt,
  });

  /// Immutable UUID; also the profile's directory name.
  final String id;
  final String name;

  /// Optional; empty string when the user left it blank.
  final String description;
  final ProfileIcon icon;
  final DateTime createdAt;

  static const maxNameLength = 48;
  static const maxDescriptionLength = 80;

  static final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static bool isValidId(String id) => uuidPattern.hasMatch(id);

  /// Returns an error message, or null when [name] is acceptable.
  static String? validateName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a profile name.';
    if (trimmed.length > maxNameLength) {
      return 'Use at most $maxNameLength characters.';
    }
    return null;
  }

  static String? validateDescription(String? description) {
    final trimmed = description?.trim() ?? '';
    if (trimmed.length > maxDescriptionLength) {
      return 'Use at most $maxDescriptionLength characters.';
    }
    return null;
  }

  WalletProfile copyWith({
    String? name,
    String? description,
    ProfileIcon? icon,
  }) {
    return WalletProfile(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon.id,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Throws [FormatException] for structurally invalid entries.
  factory WalletProfile.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || !isValidId(id)) {
      throw const FormatException('Profile has an invalid id');
    }
    if (name is! String || validateName(name) != null) {
      throw FormatException('Profile $id has an invalid name');
    }
    final description = json['description'];
    final createdAt = json['createdAt'];
    return WalletProfile(
      id: id,
      name: name.trim(),
      description: description is String ? description.trim() : '',
      icon: ProfileIcon.fromId(json['icon'] as String?),
      createdAt:
          (createdAt is String ? DateTime.tryParse(createdAt) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WalletProfile &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.icon == icon &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, description, icon, createdAt);
}
