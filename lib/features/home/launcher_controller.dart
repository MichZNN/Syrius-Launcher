import 'package:flutter/foundation.dart';

import '../../core/models/launch_status.dart';
import '../../core/models/walletconnect_summary.dart';
import '../../core/models/wallet_profile.dart';
import '../../core/platform/syrius_platform_launcher.dart';
import '../../core/services/launch_coordinator.dart';
import '../../core/services/process_monitor.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/syrius_locator.dart';

/// State for the home screen. Widgets stay presentational; every decision
/// about profiles and processes is made here or in the services below.
class LauncherController extends ChangeNotifier {
  LauncherController({
    required this._profiles,
    required this._platform,
    required this._coordinator,
    required this._monitor,
  });

  final ProfileService _profiles;
  final SyriusPlatformLauncher _platform;
  final LaunchCoordinator _coordinator;
  final ProcessMonitor _monitor;

  LauncherPhase _phase = LauncherPhase.initializing;
  LauncherPhase get phase => _phase;

  String? _initError;
  String? get initError => _initError;

  /// Set when unreadable metadata was moved aside during startup.
  String? quarantinedMetadataPath;

  Set<int> _runningPids = const {};
  String? _runningProfileId;

  List<WalletProfile> get profiles => _profiles.profiles;
  String? get selectedProfileId => _profiles.settings.selectedProfileId;
  WalletProfile? get selectedProfile =>
      _profiles.settings.profileById(selectedProfileId);

  /// The profile this launcher started and that is verified to be running.
  /// Not the same thing as the selected profile.
  String? get runningProfileId => _runningProfileId;
  bool get isSyriusRunning => _runningPids.isNotEmpty;
  bool get isLaunching => _phase == LauncherPhase.launching;

  /// v1 locks selection while any Syrius instance runs (spec 8.2).
  bool get selectionLocked => isSyriusRunning || isLaunching;

  bool get canLaunch =>
      selectedProfile != null &&
      _phase != LauncherPhase.initializing &&
      _phase != LauncherPhase.launching &&
      _phase != LauncherPhase.error;

  Future<void> initialize() async {
    try {
      quarantinedMetadataPath = await _profiles.load();
      _runningPids = await _monitor.refresh();
      _runningProfileId = _coordinator.verifiedRunningProfileId(_runningPids);
      _phase = _idlePhase;
    } catch (error) {
      _initError = '$error';
      _phase = LauncherPhase.error;
    }
    notifyListeners();
    _monitor.start(_onRunningPidsChanged);
  }

  /// Returns false when the selection is locked because Syrius is running.
  Future<bool> select(String id) async {
    if (id == selectedProfileId) return true;
    if (selectionLocked) return false;
    await _profiles.select(id);
    notifyListeners();
    return true;
  }

  Future<void> createProfile({
    required String name,
    required String description,
    required ProfileIcon icon,
  }) async {
    // While Syrius runs the selection stays locked, so the new profile is
    // added without being selected.
    await _profiles.create(
      name: name,
      description: description,
      icon: icon,
      select: !selectionLocked,
    );
    notifyListeners();
  }

  Future<void> updateProfile(
    String id, {
    required String name,
    required String description,
    required ProfileIcon icon,
  }) async {
    await _profiles.update(
      id,
      name: name,
      description: description,
      icon: icon,
    );
    notifyListeners();
  }

  /// Removal is refused while any Syrius instance runs: an instance started
  /// outside the launcher could be using any profile.
  bool canRemove(String id) => !isSyriusRunning && !isLaunching;

  Future<bool> hasWalletData(WalletProfile profile) =>
      _coordinator.hasWalletData(profile);

  Future<void> removeProfile(String id) async {
    if (!canRemove(id)) {
      throw const ProfileOperationException(
        'Syrius is running. Use "Exit wallet" inside Syrius before removing '
        'a profile.',
      );
    }
    await _profiles.remove(id);
    notifyListeners();
  }

  Future<LaunchResult> launchSelected({bool firstRunConfirmed = false}) async {
    final profile = selectedProfile;
    if (profile == null || !canLaunch) {
      return const LaunchFailed('Select a wallet profile first.');
    }
    _phase = LauncherPhase.launching;
    notifyListeners();

    LaunchResult result;
    try {
      result = await _coordinator.launch(
        profile,
        firstRunConfirmed: firstRunConfirmed,
      );
    } catch (error) {
      result = LaunchFailed('$error');
    }

    try {
      _runningPids = await _monitor.refresh();
    } catch (_) {
      // Keep the previous snapshot; the monitor will retry.
    }
    if (result is LaunchStarted) {
      _runningPids = {..._runningPids, result.handle.pid};
      _runningProfileId = result.handle.profileId;
    }
    _phase = _idlePhase;
    notifyListeners();
    return result;
  }

  bool get clearWalletConnectOnLaunch =>
      _profiles.settings.clearWalletConnectOnLaunch;

  Future<void> setClearWalletConnectOnLaunch(bool value) async {
    await _profiles.setClearWalletConnectOnLaunch(value);
    notifyListeners();
  }

  Future<void> acknowledgeWalletConnectNotice() async {
    await _profiles.acknowledgeWalletConnectNotice();
    notifyListeners();
  }

  Future<WalletConnectSummary> walletConnectSummary() =>
      _platform.walletConnectSummary();

  /// Clears the shared WalletConnect state. Refused while any Syrius runs,
  /// because a running Syrius would write its in-memory copy back.
  Future<int> clearWalletConnectNow() async {
    if (isLaunching || await _platform.isAnySyriusRunning()) {
      throw const ProfileOperationException(
        'Syrius is running. Use "Exit wallet" inside Syrius before clearing '
        'WalletConnect data.',
      );
    }
    return _platform.clearWalletConnectData();
  }

  /// Validates and remembers a user-selected Syrius app.
  Future<SyriusInstallation?> locateSyrius() async {
    final path = await _platform.pickInstallation();
    if (path == null) return null;
    return _coordinator.locate(path);
  }

  Future<void> openOfficialReleases() => _platform.openOfficialReleases();

  LauncherPhase get _idlePhase =>
      _runningPids.isEmpty ? LauncherPhase.ready : LauncherPhase.running;

  void _onRunningPidsChanged(Set<int> pids) {
    _runningPids = pids;
    if (!pids.any((pid) => pid == _profiles.settings.lastLaunch?.pid)) {
      _runningProfileId = null;
    }
    if (_phase == LauncherPhase.ready || _phase == LauncherPhase.running) {
      _phase = _idlePhase;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _monitor.stop();
    super.dispose();
  }
}
