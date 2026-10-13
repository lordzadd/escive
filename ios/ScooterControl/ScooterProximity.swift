import CoreBluetooth
import Foundation
import UserNotifications

@MainActor
final class ScooterProximity: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = ScooterProximity()
    private let defaults = UserDefaults.standard
    private var central: CBCentralManager?
    private var device: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var decoder = VicontLockProtocol()
    private var policy = ProximityPolicy()
    private var requested: (locked: Bool, sent: Date)?
    private var deadline: Task<Void, Never>?
    private var lastRead = Date.distantPast
    private var lastLog = Date.distantPast
    private var lastLock: Bool?
    private var lastWarning = Date.distantPast
    private var signal: Int?
    private var signalAt = Date.distantPast
    private var session = UUID().uuidString
    private var events: [[String: Any]] = []
    private(set) var status = "Proximity key is off."
    var enabled: Bool { defaults.bool(forKey: "proximityEnabled") }
    private var target: UUID? {
        defaults.string(forKey: "proximityPeripheral").flatMap(UUID.init(uuidString:))
    }

    func restore() {
        guard enabled else { return }
        policy.hasDeparted = defaults.bool(forKey: "proximityDeparted")
        policy.hasBeenNear = defaults.bool(forKey: "proximityNear")
        policy.manualLock = defaults.bool(forKey: "proximityManualLock")
        start()
    }

    func configure(enabled value: Bool, id: String?) throws {
        if value {
            guard let id, UUID(uuidString: id) != nil else {
                throw ScooterLocker.Failure(message: "Connect your Vicont scooter first.")
            }
            stop()
            defaults.set(id, forKey: "proximityPeripheral")
            defaults.set(true, forKey: "proximityEnabled")
            policy = ProximityPolicy(); savePolicy()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            start()
        } else {
            defaults.set(false, forKey: "proximityEnabled"); stop()
            status = "Proximity key is off."
        }
    }

    func snapshot() -> [String: Any] {
        var data: [String: Any] = ["enabled": enabled, "status": status]
        if let signal, Date().timeIntervalSince(signalAt) < 5 { data["rssi"] = signal }
        return data
    }

    func selectedDevice(_ id: String) {
        guard enabled, UUID(uuidString: id) != target else { return }
        try? configure(enabled: false, id: nil)
        status = "Proximity key stopped because the selected scooter changed."
    }

    func manual(locked: Bool) {
        guard enabled else { return }
        requested = nil; deadline?.cancel(); deadline = nil
        policy.manual(locked: locked, now: Date()); savePolicy()
        status = "Manual action takes priority. Walk away to arm approach unlocking."
        record("manual", ["locked": locked]); upload()
    }

    private func start() {
        guard central == nil, target != nil else { return }
        status = "Waiting for the scooter."
        central = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionRestoreIdentifierKey: "escive.proximity.central"
        ])
    }

    private func stop() {
        deadline?.cancel(); deadline = nil; requested = nil
        device?.delegate = nil
        if let device { central?.cancelPeripheralConnection(device) }
        device = nil; characteristic = nil
        central?.delegate = nil; central = nil
        decoder = VicontLockProtocol(); lastLock = nil; signal = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard enabled else { return }
        if central.state == .poweredOn { connect() }
        else {
            status = "Bluetooth is unavailable. Lock the scooter manually."
            policy.resetSamples(); requested = nil; savePolicy()
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard enabled else { return }
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        device = restored.first { $0.identifier == target }
        device?.delegate = self
        if let device, device.state == .connected { discover(device) }
    }

    private func connect() {
        guard enabled, let central, central.state == .poweredOn, let target else { return }
        if device == nil { device = central.retrievePeripherals(withIdentifiers: [target]).first }
        guard let device else { status = "Open eScive and connect your scooter first."; return }
        device.delegate = self
        if device.state == .connected { discover(device) }
        else if device.state == .disconnected { central.connect(device) }
    }

    private func discover(_ peripheral: CBPeripheral) {
        guard characteristic == nil else { return }
        peripheral.discoverServices([CBUUID(string: "fff0"), CBUUID(string: "fee0")])
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        decoder = VicontLockProtocol(); characteristic = nil; lastLock = nil
        lastRead = .distantPast; policy.resetSamples()
        status = "Reading scooter status."
        record("connected"); discover(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard enabled, peripheral === device else { return }
        if (requested != nil || !decoder.fresh() || !decoder.brake || !decoder.electronic),
           Date().timeIntervalSince(lastWarning) > 30 {
            lastWarning = Date()
            notify("Connection lost. Locking is not confirmed. Check your scooter.")
        }
        requested = nil; deadline?.cancel(); deadline = nil
        characteristic = nil; decoder = VicontLockProtocol(); lastLock = nil; signal = nil
        policy.disconnected(); savePolicy()
        status = "Out of range. A lost connection does not confirm locking."
        record("disconnected"); upload(); connect()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        status = "Connection failed. Lock the scooter manually."
        record("connection_failed"); upload()
        // A pending connection waits for the known peripheral to return.
        connect()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { status = "Could not read scooter services."; return }
        for service in peripheral.services ?? [] {
            let id = service.uuid == CBUUID(string: "fff0") ? "fff1" : "fee2"
            peripheral.discoverCharacteristics([CBUUID(string: id)], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, characteristic == nil else { return }
        guard let c = service.characteristics?.first(where: {
            ($0.properties.contains(.notify) || $0.properties.contains(.indicate)) &&
            ($0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse))
        }) else { return }
        characteristic = c
        if c.isNotifying { hello() } else { peripheral.setNotifyValue(true, for: c) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.isNotifying else { return }
        hello()
    }

    private func hello() {
        write([0xfa, 0xaf, 0xa5, 0x5a, 1, 0, 0x5b])
        let current = device
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, self.enabled, self.device === current, self.decoder.header == nil else { return }
            self.write([0xfa, 0xaf, 0xa5, 0xfa, 1, 0, 0x5b])
        }
    }

    private func write(_ bytes: [UInt8]) {
        guard enabled, let device, let characteristic, device.state == .connected else { return }
        record("tx", ["bytes": bytes])
        device.writeValue(Data(bytes), for: characteristic,
                          type: characteristic.properties.contains(.write) ? .withResponse : .withoutResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error, requested != nil { finish(error.localizedDescription) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard enabled, error == nil, let value = characteristic.value else { return }
        decoder.receive([UInt8](value))
        let now = Date()
        if decoder.fresh(now: now), decoder.electronic == decoder.brake {
            if let requested {
                if decoder.confirmed(requested.locked, after: requested.sent, now: now) { finish(nil) }
            } else if let lastLock, lastLock != decoder.brake {
                // Includes commands from the phone, widget, or another app.
                manual(locked: decoder.brake)
            }
            lastLock = decoder.brake
        }
        // Notifications wake the app in the background. Do not depend on a Flutter timer.
        if now.timeIntervalSince(lastRead) >= 1 {
            lastRead = now; peripheral.readRSSI()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard enabled else { return }
        let now = Date()
        guard error == nil, now.timeIntervalSince(lastRead) < 2 else { policy.resetSamples(); return }
        signal = RSSI.intValue; signalAt = now
        let stationary = decoder.fresh(now: now) && decoder.speed == 0 && decoder.electronic == decoder.brake
        if now.timeIntervalSince(lastLog) >= 5 {
            lastLog = now
            record("signal", ["rssi": RSSI.intValue, "stationary": stationary,
                              "electronic": decoder.electronic, "brake": decoder.brake])
            upload()
        }
        guard requested == nil else { return }
        let target = policy.sample(rssi: RSSI.intValue, stationary: stationary, locked: decoder.brake, now: now)
        savePolicy()
        if target == nil {
            if !stationary { status = "Waiting for fresh status and zero speed." }
            else if policy.manualLock { status = "Manual lock held. Walk away before approach unlocking." }
            else if policy.hasBeenNear { status = "Armed. Walk away to lock the scooter." }
            else if policy.hasDeparted { status = "Waiting for your return." }
            else { status = "Stay beside the scooter for a few seconds to arm it." }
        }
        guard let target, let header = decoder.header else { return }
        requested = (target, now)
        status = target ? "Locking as you walk away…" : "Unlocking as you approach…"
        write(VicontLockProtocol.lockPacket(header, locked: target))
        deadline?.cancel()
        deadline = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.finish("No scooter confirmation. Check your scooter.")
        }
    }

    private func finish(_ error: String?) {
        guard let requested else { return }
        self.requested = nil; deadline?.cancel(); deadline = nil
        policy.completed(now: Date())
        if error != nil {
            // Require a new departure/approach cycle instead of retrying unattended.
            policy.hasBeenNear = false; policy.hasDeparted = false
        } else if requested.locked {
            policy.hasBeenNear = false
        } else {
            policy.hasDeparted = false
        }
        savePolicy()
        status = error ?? (requested.locked ? "Scooter lock confirmed." : "Scooter unlock confirmed.")
        record("result", ["locked": requested.locked, "confirmed": error == nil, "message": status])
        upload(); notify(status)
    }

    private func savePolicy() {
        defaults.set(policy.hasDeparted, forKey: "proximityDeparted")
        defaults.set(policy.hasBeenNear, forKey: "proximityNear")
        defaults.set(policy.manualLock, forKey: "proximityManualLock")
    }

    private func notify(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "eScive proximity key"; content.body = message; content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString,
                                                                      content: content, trigger: nil))
    }

    private func record(_ event: String, _ data: [String: Any] = [:]) {
        var data = data; data["source"] = "proximity"; data["event"] = event
        if events.count >= 50 { events.removeFirst() }
        events.append(["session": session, "time": ISO8601DateFormatter().string(from: Date()),
                       "kind": "parking", "data": data])
    }

    private func upload() {
        guard !events.isEmpty,
              let endpoint = defaults.string(forKey: "scooterWidgetDiagnosticsURL"),
              let url = URL(string: endpoint), url.scheme == "https",
              let token = defaults.string(forKey: "scooterWidgetDiagnosticsToken") else { return }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 8
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: events); events.removeAll()
        URLSession.shared.dataTask(with: request).resume()
    }
}
