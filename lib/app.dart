import 'package:flutter/material.dart';

import 'core/theme/launcher_theme.dart';
import 'features/home/launcher_controller.dart';
import 'features/home/launcher_page.dart';

class SyriusLauncherApp extends StatelessWidget {
  const SyriusLauncherApp({
    super.key,
    required this.controller,
    this.showPlatformMenus = true,
  });

  final LauncherController controller;
  final bool showPlatformMenus;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syrius Launcher',
      debugShowCheckedModeBanner: false,
      theme: buildLauncherTheme(),
      themeMode: ThemeMode.dark,
      home: LauncherPage(
        controller: controller,
        showPlatformMenus: showPlatformMenus,
      ),
    );
  }
}
