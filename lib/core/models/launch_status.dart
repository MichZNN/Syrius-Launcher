import 'package:flutter/foundation.dart';

/// Runtime state machine from spec section 8.2.
enum LauncherPhase { initializing, ready, launching, running, error }

/// A Syrius process started by this launcher.
@immutable
class LaunchHandle {
  const LaunchHandle({
    required this.pid,
    required this.profileId,
    required this.startedAt,
  });

  final int pid;
  final String profileId;
  final DateTime startedAt;
}

/// Outcome of a launch attempt. Only [LaunchStarted] means a process is
/// running; it still does not prove the Syrius UI finished initializing.
sealed class LaunchResult {
  const LaunchResult();
}

final class LaunchStarted extends LaunchResult {
  const LaunchStarted(this.handle);
  final LaunchHandle handle;
}

final class LaunchBlockedAlreadyRunning extends LaunchResult {
  const LaunchBlockedAlreadyRunning();
}

final class LaunchSyriusNotFound extends LaunchResult {
  const LaunchSyriusNotFound([this.detail]);
  final String? detail;
}

/// The selected profile has no Syrius wallet yet and an ordinary Syrius
/// installation exists under the real home; the user must choose how to
/// proceed (spec 5.2).
final class LaunchNeedsFirstRunChoice extends LaunchResult {
  const LaunchNeedsFirstRunChoice();
}

/// The user has not yet seen the warning that Syrius's WalletConnect state
/// is shared between all profiles.
final class LaunchNeedsWalletConnectNotice extends LaunchResult {
  const LaunchNeedsWalletConnectNotice();
}

final class LaunchFailed extends LaunchResult {
  const LaunchFailed(this.message);
  final String message;
}

final class LaunchExitedEarly extends LaunchResult {
  const LaunchExitedEarly();
}
