import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  private var nativeBridge: LauncherNativeBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    nativeBridge = LauncherNativeBridge(
      messenger: flutterViewController.engine.binaryMessenger,
      window: self
    )

    super.awakeFromNib()
  }
}

/// Small, explicit native surface for the launcher. Every method only reads
/// bundle/process metadata, opens a fixed-purpose panel, or moves one path to
/// the Trash. Nothing here executes shell commands.
final class LauncherNativeBridge {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    self.channel = FlutterMethodChannel(
      name: "syrius_launcher/macos",
      binaryMessenger: messenger
    )
    self.window = window
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "applicationsForBundleIdentifier":
      guard let bundleId = args["bundleIdentifier"] as? String else {
        return result(badArgs(call))
      }
      let urls = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleId)
      result(urls.map { $0.path })

    case "inspectBundle":
      guard let path = args["path"] as? String else { return result(badArgs(call)) }
      result(inspectBundle(atPath: path))

    case "runningProcessIds":
      guard let bundleId = args["bundleIdentifier"] as? String else {
        return result(badArgs(call))
      }
      let pids = NSWorkspace.shared.runningApplications
        .filter { $0.bundleIdentifier == bundleId && !$0.isTerminated }
        .map { Int($0.processIdentifier) }
      result(pids)

    case "moveToTrash":
      guard let path = args["path"] as? String else { return result(badArgs(call)) }
      var trashedUrl: NSURL?
      do {
        try FileManager.default.trashItem(
          at: URL(fileURLWithPath: path),
          resultingItemURL: &trashedUrl
        )
        result(trashedUrl?.path)
      } catch {
        result(FlutterError(
          code: "trash_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }

    case "pickApplication":
      pickApplication(result: result)

    case "openUrl":
      guard let raw = args["url"] as? String,
            let url = URL(string: raw),
            url.scheme == "https" else {
        return result(badArgs(call))
      }
      result(NSWorkspace.shared.open(url))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func inspectBundle(atPath path: String) -> [String: Any]? {
    // Bundle(url:) resolves CFBundleExecutable from Info.plist, so the
    // executable name (e.g. "s y r i u s") is never guessed.
    guard let bundle = Bundle(url: URL(fileURLWithPath: path)) else { return nil }
    let info = bundle.infoDictionary ?? [:]
    return [
      "bundlePath": bundle.bundleURL.path,
      "bundleIdentifier": bundle.bundleIdentifier as Any,
      "executableName": info["CFBundleExecutable"] as Any,
      "executablePath": bundle.executableURL?.path as Any,
      "shortVersion": info["CFBundleShortVersionString"] as Any,
    ]
  }

  private func pickApplication(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.title = "Locate Syrius"
    panel.message = "Select the installed Syrius application (s y r i u s.app)."
    panel.prompt = "Choose"
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.treatsFilePackagesAsDirectories = false
    panel.allowedContentTypes = [.application]
    panel.directoryURL = URL(fileURLWithPath: "/Applications")

    let completion: (NSApplication.ModalResponse) -> Void = { response in
      result(response == .OK ? panel.url?.path : nil)
    }
    if let window = window {
      panel.beginSheetModal(for: window, completionHandler: completion)
    } else {
      completion(panel.runModal())
    }
  }

  private func badArgs(_ call: FlutterMethodCall) -> FlutterError {
    FlutterError(
      code: "bad_arguments",
      message: "Invalid arguments for \(call.method)",
      details: nil
    )
  }
}
