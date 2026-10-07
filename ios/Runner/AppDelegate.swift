import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
  private var watchChannel: FlutterMethodChannel?
  private var snapshot: [String: Any] = ["ready": false]
  private var requests = Set<String>()

  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "escive/watch", binaryMessenger: controller.binaryMessenger)
      watchChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "installation" {
          let bundle = Bundle.main
          let extensions = (try? FileManager.default.contentsOfDirectory(at: bundle.builtInPlugInsURL ?? bundle.bundleURL.appendingPathComponent("PlugIns"), includingPropertiesForKeys: nil)) ?? []
          result([
            "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "build": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "bundleId": bundle.bundleIdentifier ?? "unknown",
            "extensions": extensions.compactMap { url -> [String: String]? in
              guard url.pathExtension == "appex", let plugin = Bundle(url: url) else { return nil }
              return ["id": plugin.bundleIdentifier ?? "unknown", "name": url.lastPathComponent,
                      "version": plugin.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"]
            },
            "shortcutTitles": UIApplication.shared.shortcutItems?.map { $0.localizedTitle } ?? []
          ])
          return
        }
        guard call.method == "snapshot", let data = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented); return
        }
        // Keep widget configuration in the host app. It needs no App Group entitlement.
        let defaults = UserDefaults.standard
        if let address = data["bluetoothAddress"] as? String, UUID(uuidString: address) != nil {
          defaults.set(address, forKey: "scooterWidgetPeripheral")
        } else {
          defaults.removeObject(forKey: "scooterWidgetPeripheral")
        }
        defaults.set(data["diagnosticsURL"], forKey: "scooterWidgetDiagnosticsURL")
        defaults.set(data["diagnosticsToken"], forKey: "scooterWidgetDiagnosticsToken")
        var watchData = data
        watchData.removeValue(forKey: "diagnosticsURL")
        watchData.removeValue(forKey: "diagnosticsToken")
        watchData.removeValue(forKey: "bluetoothAddress")
        self?.snapshot = watchData
        if WCSession.isSupported(), WCSession.default.activationState == .activated,
           WCSession.default.isPaired, WCSession.default.isWatchAppInstalled {
          do { try WCSession.default.updateApplicationContext(watchData) }
          catch { result(FlutterError(code: "watch", message: error.localizedDescription, details: nil)); return }
        }
        result(nil)
      }
    }
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { replyHandler(["error": "Open eScive on iPhone."]); return }
      if message["action"] as? String == "refresh" { replyHandler(self.snapshot); return }
      guard let id = message["requestId"] as? String,
            let issued = message["timestamp"] as? Double,
            abs(Date().timeIntervalSince1970 - issued) < 10,
            !self.requests.contains(id), let channel = self.watchChannel else {
        replyHandler(["error": "Request expired. Try again."]); return
      }
      if self.requests.count > 256 { self.requests.removeAll() }
      self.requests.insert(id)
      var replied = false
      let finish: ([String: Any]) -> Void = { value in
        guard !replied else { return }; replied = true; replyHandler(value)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
        finish(["error": "No response. Check the scooter before trying again."])
      }
      channel.invokeMethod("command", arguments: message) { result in
        if let error = result as? FlutterError { finish(["error": error.message ?? "Command failed."]) }
        else if let response = result as? [String: Any] { finish(response) }
        else { finish(["error": "Open eScive on iPhone."]) }
      }
    }
  }
}
