import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/persistence/json_profile_repository.dart';
import 'core/platform/macos_native_bridge.dart';
import 'core/platform/syrius_platform_launcher.dart';
import 'core/services/launch_coordinator.dart';
import 'core/services/process_monitor.dart';
import 'core/services/profile_service.dart';
import 'core/theme/launcher_palette.dart';
import 'features/home/launcher_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureWindow();

  final home = Platform.environment['HOME']!;
  final platform = createPlatformLauncher();
  final profiles = ProfileService(
    // Launcher metadata only; Syrius's own paths come from its SDK rules.
    repository: JsonProfileRepository(await getApplicationSupportDirectory()),
    profilesRootPath: p.join(home, 'SyriusProfiles'),
    trash: Platform.isMacOS ? const MacosNativeBridge() : const _NoTrash(),
  );
  final controller = LauncherController(
    profiles: profiles,
    platform: platform,
    coordinator: LaunchCoordinator(platform: platform, profiles: profiles),
    monitor: ProcessMonitor(platform: platform),
  );

  runApp(SyriusLauncherApp(controller: controller));
  await controller.initialize();
}

Future<void> _configureWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(480, 560),
    minimumSize: Size(420, 480),
    maximumSize: Size(560, 1000),
    center: true,
    title: 'Syrius Launcher',
    backgroundColor: LauncherPalette.background,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setBrightness(Brightness.dark);
    await windowManager.show();
    await windowManager.focus();
  });
}

class _NoTrash implements ProfileTrash {
  const _NoTrash();

  @override
  Future<String?> moveToTrash(String path) async =>
      throw const TrashException('Moving to Trash is not supported here yet.');
}
