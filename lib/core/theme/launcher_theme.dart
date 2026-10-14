import 'package:flutter/material.dart';

import 'launcher_palette.dart';

ThemeData buildLauncherTheme() {
  const scheme = ColorScheme.dark(
    primary: LauncherPalette.primaryGreen,
    onPrimary: LauncherPalette.buttonText,
    secondary: LauncherPalette.primaryGreen,
    onSecondary: LauncherPalette.buttonText,
    surface: LauncherPalette.background,
    onSurface: LauncherPalette.headingText,
    surfaceContainerHighest: LauncherPalette.profileBackground,
    onSurfaceVariant: LauncherPalette.secondaryText,
    outline: LauncherPalette.separator,
    outlineVariant: LauncherPalette.separator,
    error: LauncherPalette.errorText,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: LauncherPalette.background,
    splashFactory: NoSplash.splashFactory,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: LauncherPalette.separator),
  );

  return base.copyWith(
    dialogTheme: DialogThemeData(
      backgroundColor: LauncherPalette.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LauncherPalette.separator),
      ),
      titleTextStyle: const TextStyle(
        color: LauncherPalette.headingText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color: LauncherPalette.secondaryText,
        fontSize: 13,
        height: 1.45,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LauncherPalette.profileBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: LauncherPalette.secondaryText),
      floatingLabelStyle: const TextStyle(color: LauncherPalette.primaryGreen),
      helperStyle: const TextStyle(color: LauncherPalette.headerSubtitle),
      counterStyle: const TextStyle(color: LauncherPalette.headerSubtitle),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: LauncherPalette.primaryGreen),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: LauncherPalette.errorText),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: LauncherPalette.errorText),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: LauncherPalette.primaryGreen,
      selectionColor: LauncherPalette.primaryGreen.withValues(alpha: 0.3),
      selectionHandleColor: LauncherPalette.primaryGreen,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LauncherPalette.primaryGreen,
        foregroundColor: LauncherPalette.buttonText,
        disabledBackgroundColor: LauncherPalette.disabledButton,
        disabledForegroundColor: LauncherPalette.buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LauncherPalette.secondaryText,
        textStyle: const TextStyle(fontSize: 14),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: LauncherPalette.headerIconBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: LauncherPalette.separator),
      ),
      textStyle: const TextStyle(
        color: LauncherPalette.headingText,
        fontSize: 13,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: LauncherPalette.headerIconBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LauncherPalette.separator),
      ),
      textStyle: const TextStyle(
        color: LauncherPalette.headingText,
        fontSize: 12,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: LauncherPalette.buttonText,
    ),
  );
}
