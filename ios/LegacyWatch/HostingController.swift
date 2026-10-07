import WatchKit
import SwiftUI
import WatchConnectivity

final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchModel()
    @Published var snapshot: [String: Any] = [:]
    @Published var message = "Open eScive on iPhone."
    @Published var busy = false
    @Published var now = Date()
    private var timer: Timer?
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.now = Date() }
    }
    var ready: Bool {
        let timestamp = snapshot["timestamp"] as? Double ?? 0
        return snapshot["ready"] as? Bool == true && now.timeIntervalSince1970 - timestamp < 5 &&
            WCSession.default.isReachable && !busy
    }
    func send(_ action: String) {
        guard !busy, WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            message = "Open eScive on iPhone."; return
        }
        if action != "refresh" && !ready { message = "Refresh scooter data first."; return }
        busy = true
        let request: [String: Any] = ["action": action, "requestId": UUID().uuidString,
            "timestamp": Date().timeIntervalSince1970, "deviceId": snapshot["deviceId"] as? String ?? ""]
        WCSession.default.sendMessage(request, replyHandler: { response in
            DispatchQueue.main.async {
                self.busy = false
                if action == "refresh" { self.snapshot = response }
                self.message = response["error"] as? String ??
                    (response["sent"] as? Bool == true ? "Sent. Check scooter feedback." : action == "refresh" ? "Data refreshed." : "Command not sent.")
            }
        }, errorHandler: { error in
            DispatchQueue.main.async { self.busy = false; self.message = error.localizedDescription }
        })
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.snapshot = session.receivedApplicationContext }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.snapshot = applicationContext }
    }
}

struct ScooterView: View {
    @ObservedObject var model = WatchModel.shared
    var body: some View {
        ScrollView {
            VStack {
                Text(model.snapshot["name"] as? String ?? "eScive").font(.headline)
                Text(model.ready ? "Connected" : "Data unavailable")
                Text("Battery \(model.snapshot["battery"] as? Int ?? 0)%")
                Text(String(format: "%.1f km/h", model.snapshot["speed"] as? Double ?? 0))
                Button("Refresh") { self.model.send("refresh") }.disabled(model.busy)
                Button(model.snapshot["locked"] as? Bool == true ? "Unlock" : "Lock") {
                    self.model.send(self.model.snapshot["locked"] as? Bool == true ? "unlock" : "lock")
                }.disabled(!model.ready)
                Button(model.snapshot["light"] as? Bool == true ? "Light off" : "Light on") {
                    self.model.send(self.model.snapshot["light"] as? Bool == true ? "lightOff" : "lightOn")
                }.disabled(!model.ready)
                Text(model.message).font(.footnote)
            }
        }
    }
}

final class HostingController: WKHostingController<ScooterView> {
    override var body: ScooterView { ScooterView() }
}
final class ExtensionDelegate: NSObject, WKExtensionDelegate {}
