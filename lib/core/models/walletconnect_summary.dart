import 'package:flutter/foundation.dart';

/// What Syrius currently has stored for WalletConnect.
///
/// [storageKeys] is not a number of connections: the WalletConnect library
/// always keeps many keys (one per storage version and kind), even when no
/// dApp is connected.
@immutable
class WalletConnectSummary {
  const WalletConnectSummary({
    required this.sessions,
    required this.pairings,
    required this.storageKeys,
  });

  static const empty = WalletConnectSummary(
    sessions: 0,
    pairings: 0,
    storageKeys: 0,
  );

  final int sessions;
  final int pairings;
  final int storageKeys;

  bool get hasConnections => sessions > 0 || pairings > 0;
}
