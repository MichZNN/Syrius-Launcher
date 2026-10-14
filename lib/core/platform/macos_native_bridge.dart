import 'package:flutter/services.dart';

import '../services/profile_service.dart';
import '../services/syrius_locator.dart';

/// Dart side of `LauncherNativeBridge` in macos/Runner/MainFlutterWindow.swift.
class MacosNativeBridge implements BundleInspector, ProfileTrash {
  const MacosNativeBridge();

  static const _channel = MethodChannel('syrius_launcher/macos');

  /// Installed copies of an app, as known to Launch Services.
  Future<List<String>> applicationsForBundleIdentifier(String bundleId) async {
    final paths = await _channel.invokeListMethod<String>(
      'applicationsForBundleIdentifier',
      {'bundleIdentifier': bundleId},
    );
    return paths ?? const [];
  }

  @override
  Future<BundleInfo?> inspect(String appPath) async {
    final info = await _channel.invokeMapMethod<String, Object?>(
      'inspectBundle',
      {'path': appPath},
    );
    if (info == null) return null;
    return BundleInfo(
      bundleIdentifier: info['bundleIdentifier'] as String?,
      executableName: info['executableName'] as String?,
      shortVersion: info['shortVersion'] as String?,
    );
  }

  Future<Set<int>> runningProcessIds(String bundleId) async {
    final pids = await _channel.invokeListMethod<int>('runningProcessIds', {
      'bundleIdentifier': bundleId,
    });
    return {...?pids};
  }

  @override
  Future<String?> moveToTrash(String path) async {
    try {
      return await _channel.invokeMethod<String>('moveToTrash', {'path': path});
    } on PlatformException catch (error) {
      throw TrashException(error.message ?? 'Moving to Trash failed.');
    }
  }

  Future<String?> pickApplication() =>
      _channel.invokeMethod<String>('pickApplication');

  Future<void> openUrl(String url) =>
      _channel.invokeMethod<bool>('openUrl', {'url': url});
}
