import 'package:flutter/painting.dart';

/// Locked color tokens from spec section 4.3. Dark only for v1.
abstract final class LauncherPalette {
  static const background = Color(0xFF15191F);
  static const headerIconBackground = Color(0xFF252D38);
  static const profileBackground = Color(0xFF232A34);
  static const separator = Color(0xFF333C48);
  static const primaryGreen = Color(0xFF6FF34D);
  static const headingText = Color(0xFFF3F6FA);
  static const profileTitleText = Color(0xFFFFFFFF);
  static const secondaryText = Color(0xFFA5ADBA);
  static const headerSubtitle = Color(0xFF98A3B6);
  static const buttonText = Color(0xFF101810);
  static const selectedBadgeBackground = Color(0xFF263C2D);
  static const hoverProfileBackground = Color(0xFF2B3541);
  static const disabledButton = Color(0xFF52644E);

  /// Not part of the locked home-screen palette; used only for error text in
  /// dialogs.
  static const errorText = Color(0xFFFF7A6E);
}
