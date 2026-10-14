import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/syrius_platform_launcher.dart';

/// Polls for running Syrius processes so the launcher notices when Syrius
/// exits (or is started outside the launcher). Syrius is launched detached,
/// so polling replaces waiting on an exit code.
class ProcessMonitor {
  ProcessMonitor({
    required this._platform,
    this.interval = const Duration(seconds: 2),
  });

  final SyriusPlatformLauncher _platform;
  final Duration interval;

  Timer? _timer;
  bool _polling = false;
  Set<int> _last = const {};

  Set<int> get runningPids => _last;

  void start(ValueChanged<Set<int>> onChanged) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      if (_polling) return;
      _polling = true;
      try {
        final previous = _last;
        final current = await refresh();
        if (!setEquals(previous, current)) onChanged(current);
      } catch (_) {
        // A failed poll is retried on the next tick.
      } finally {
        _polling = false;
      }
    });
  }

  Future<Set<int>> refresh() async {
    _last = Set.unmodifiable(await _platform.runningSyriusPids());
    return _last;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
