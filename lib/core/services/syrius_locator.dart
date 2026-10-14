import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Values read from an application bundle's Info.plist.
@immutable
class BundleInfo {
  const BundleInfo({
    required this.bundleIdentifier,
    required this.executableName,
    this.shortVersion,
  });

  final String? bundleIdentifier;

  /// `CFBundleExecutable`. For Syrius this is `s y r i u s` (with spaces).
  final String? executableName;
  final String? shortVersion;
}

abstract interface class BundleInspector {
  /// Returns null when [appPath] is not a readable application bundle.
  Future<BundleInfo?> inspect(String appPath);
}

/// A verified, installed official Syrius application.
@immutable
class SyriusInstallation {
  const SyriusInstallation({
    required this.appPath,
    required this.executablePath,
    required this.executableName,
    this.version,
  });

  final String appPath;
  final String executablePath;
  final String executableName;
  final String? version;
}

class SyriusInstallationException implements Exception {
  const SyriusInstallationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Finds and validates the official Syrius `.app` on macOS (spec 6.1).
class SyriusLocator {
  SyriusLocator({required this.inspector, required this.homeDirectory});

  static const bundleIdentifier = 'network.zenon.syrius';
  static const defaultAppName = 's y r i u s.app';

  final BundleInspector inspector;
  final String homeDirectory;

  List<String> get conventionalLocations => [
    p.join('/Applications', defaultAppName),
    p.join(homeDirectory, 'Applications', defaultAppName),
  ];

  /// Tries [savedPath] first, then Launch Services results, then the
  /// conventional install locations. Returns the first valid installation.
  Future<SyriusInstallation?> discover({
    String? savedPath,
    List<String> launchServicesPaths = const [],
  }) async {
    final seen = <String>{};
    final candidates = [
      ?savedPath,
      ...launchServicesPaths,
      ...conventionalLocations,
    ];
    for (final candidate in candidates) {
      if (!seen.add(p.normalize(candidate))) continue;
      try {
        return await validate(candidate);
      } on SyriusInstallationException {
        continue;
      }
    }
    return null;
  }

  /// Verifies bundle identity and resolves the executable through
  /// `CFBundleExecutable`. Throws [SyriusInstallationException].
  Future<SyriusInstallation> validate(String appPath) async {
    final normalized = p.normalize(p.absolute(appPath));
    if (p.extension(normalized).toLowerCase() != '.app') {
      throw const SyriusInstallationException(
        'The selected item is not an application bundle.',
      );
    }
    if (!await FileSystemEntity.isDirectory(normalized)) {
      throw SyriusInstallationException('No application found at $normalized.');
    }

    final info = await inspector.inspect(normalized);
    if (info == null) {
      throw const SyriusInstallationException(
        'The application bundle could not be read.',
      );
    }
    if (info.bundleIdentifier != bundleIdentifier) {
      throw SyriusInstallationException(
        'This is not the official Syrius app '
        '(bundle identifier "${info.bundleIdentifier ?? 'unknown'}").',
      );
    }

    final executableName = info.executableName;
    if (executableName == null ||
        executableName.isEmpty ||
        executableName.contains('/') ||
        executableName == '.' ||
        executableName == '..') {
      throw const SyriusInstallationException(
        'The Syrius bundle has an invalid CFBundleExecutable entry.',
      );
    }

    final macOsDir = p.join(normalized, 'Contents', 'MacOS');
    final executablePath = p.join(macOsDir, executableName);
    if (!p.isWithin(macOsDir, executablePath)) {
      throw const SyriusInstallationException(
        'The Syrius executable is outside its application bundle.',
      );
    }
    // Do not follow symlinks: the executable must be a regular file inside
    // the bundle.
    final type = await FileSystemEntity.type(
      executablePath,
      followLinks: false,
    );
    if (type != FileSystemEntityType.file) {
      throw const SyriusInstallationException(
        'The Syrius executable is missing from the application bundle.',
      );
    }
    final stat = await File(executablePath).stat();
    if (stat.mode & 0x49 == 0) {
      throw const SyriusInstallationException(
        'The Syrius executable is not marked as executable.',
      );
    }

    return SyriusInstallation(
      appPath: normalized,
      executablePath: executablePath,
      executableName: executableName,
      version: info.shortVersion,
    );
  }
}
