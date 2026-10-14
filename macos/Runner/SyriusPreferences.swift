import Foundation

/// Access to Syrius's macOS preferences domain (NSUserDefaults), which is
/// shared by every launcher profile because macOS does not resolve it through
/// HOME. Only WalletConnect keys are ever read or removed.
enum SyriusPreferences {
  static let domain = "network.zenon.syrius"

  /// Prefix used by Flutter `shared_preferences` + WalletConnect v2.
  static let walletConnectPrefix = "flutter.wc@2:"

  static func walletConnectKeys(domain: String = domain) -> [String] {
    let appId = domain as CFString
    CFPreferencesAppSynchronize(appId)
    let keys = CFPreferencesCopyKeyList(
      appId,
      kCFPreferencesCurrentUser,
      kCFPreferencesAnyHost
    ) as? [String] ?? []
    return keys.filter { $0.hasPrefix(walletConnectPrefix) }
  }

  /// Number of stored WalletConnect sessions and pairings. The store keeps
  /// many keys per kind (one per storage version, plus legacy keys that only
  /// hold a version marker), so the key count says nothing about how many
  /// connections exist. This reads the newest versioned key of each kind
  /// and only counts its items.
  static func walletConnectSummary(domain: String = domain) -> [String: Int] {
    let appId = domain as CFString
    let keys = walletConnectKeys(domain: domain)

    func count(kind: String) -> Int {
      let versioned = keys
        .filter { $0.contains("//") && $0.hasSuffix("//\(kind)") }
        .sorted { $0.compare($1, options: .numeric) == .orderedAscending }
      guard let key = versioned.last,
            let text = CFPreferencesCopyAppValue(key as CFString, appId) as? String,
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data)
      else { return 0 }
      if let dict = json as? [String: Any] { return dict.count }
      if let list = json as? [Any] { return list.count }
      return 0
    }

    return [
      "keys": keys.count,
      "sessions": count(kind: "sessions"),
      "pairings": count(kind: "pairings"),
    ]
  }

  /// Removes all WalletConnect keys through cfprefsd (never by editing the
  /// plist file directly). Returns the number of removed keys.
  static func clearWalletConnect(domain: String = domain) -> Int {
    let appId = domain as CFString
    let keys = walletConnectKeys(domain: domain)
    for key in keys {
      CFPreferencesSetValue(
        key as CFString,
        nil,
        appId,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
      )
    }
    CFPreferencesAppSynchronize(appId)
    return keys.count
  }
}
