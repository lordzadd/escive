import Foundation
import CoreBluetooth

@MainActor
final class ScooterLocker: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = ScooterLocker()
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var pending: CheckedContinuation<Void, Error>?
    private var timeout: Task<Void, Never>?
    private var target: UUID?
    private var decoder = VicontLockProtocol()
    private var requestedLock = true
    private var toggleResolved = false
    private var sentAt: Date?
    private var writeAcknowledged = false
    private var helloTasks: [Task<Void, Never>] = []
    private var operation = UUID()
    private var events: [[String: Any]] = []

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func toggleLock() async throws {
        guard pending == nil else { throw Failure(message: "A lock request is already running.") }
        guard let id = UserDefaults.standard.string(forKey: "scooterWidgetPeripheral"),
              let uuid = UUID(uuidString: id) else {
            throw Failure(message: "Open eScive and connect your scooter once to set up the widget.")
        }
        toggleResolved = false
        target = uuid; decoder = VicontLockProtocol(); sentAt = nil
        writeAcknowledged = false; operation = UUID(); events = []
        record("parking", ["requested": "toggle", "source": "lockWidget"])
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            timeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finish("No scooter confirmation. Check that the scooter is on and nearby.")
            }
            if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
            else { connect() }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) { connect() }

    private func connect() {
        guard pending != nil, peripheral == nil, let central else { return }
        guard central.state == .poweredOn else {
            if central.state != .unknown && central.state != .resetting {
                finish("Bluetooth is unavailable. Enable Bluetooth and try again.")
            }
            return
        }
        guard let target,
              let device = central.retrievePeripherals(withIdentifiers: [target]).first else {
            finish("Open eScive and reconnect your scooter first."); return
        }
        peripheral = device; device.delegate = self
        central.connect(device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard pending != nil else { return }
        peripheral.discoverServices([CBUUID(string: "fff0"), CBUUID(string: "fee0")])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finish("Could not connect to the scooter.")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if pending != nil { finish("The scooter disconnected before scooter confirmation.") }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { finish("Could not read scooter services."); return }
        for service in peripheral.services ?? [] {
            let id = service.uuid == CBUUID(string: "fff0") ? "fff1" : "fee2"
            peripheral.discoverCharacteristics([CBUUID(string: id)], for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard pending != nil, characteristic == nil, error == nil else { return }
        guard let c = service.characteristics?.first(where: {
            ($0.properties.contains(.notify) || $0.properties.contains(.indicate)) &&
            ($0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse))
        }) else { return }
        characteristic = c; peripheral.setNotifyValue(true, for: c)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard pending != nil, characteristic.isNotifying, error == nil else {
            finish("Could not receive scooter status."); return
        }
        write([0xfa, 0xaf, 0xa5, 0x5a, 1, 0, 0x5b])
        let id = operation
        helloTasks.append(Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self, self.operation == id, self.pending != nil, self.sentAt == nil else { return }
            self.write([0xfa, 0xaf, 0xa5, 0xfa, 1, 0, 0x5b])
        })
    }
    private func write(_ bytes: [UInt8]) {
        guard let peripheral, let characteristic, pending != nil else { return }
        record("tx", ["bytes": bytes, "source": "lockWidget"])
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(Data(bytes), for: characteristic, type: type)
        if sentAt != nil && type == .withoutResponse { writeAcknowledged = true }
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil { finish("The Bluetooth write failed."); return }
        if sentAt != nil { writeAcknowledged = true; evaluate() }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard pending != nil, error == nil, let data = characteristic.value else { return }
        record("rx", ["bytes": [UInt8](data), "source": "lockWidget"])
        decoder.receive([UInt8](data)); evaluate()
    }
    private func evaluate() {
        guard pending != nil, decoder.fresh(), let speed = decoder.speed else { return }
        guard speed <= 1 else { finish("Stop the scooter before changing the lock."); return }
        if !toggleResolved {
            // Wait through any in-progress transition before deciding the opposite state.
            guard let target = decoder.toggleTarget() else { return }
            requestedLock = target
            toggleResolved = true
            record("parking", ["requested": requestedLock, "source": "lockWidget"])
        }
        if let sentAt {
            if writeAcknowledged, decoder.confirmed(requestedLock, after: sentAt) { finish(nil) }
        } else if decoder.electronic == requestedLock && decoder.brake == requestedLock {
            finish(nil)
        } else if let header = decoder.header {
            sentAt = Date()
            helloTasks.forEach { $0.cancel() }; helloTasks.removeAll()
            write(VicontLockProtocol.lockPacket(header, locked: requestedLock))
        }
    }
    private func finish(_ message: String?) {
        guard let continuation = pending else { return }
        pending = nil; timeout?.cancel(); timeout = nil
        helloTasks.forEach { $0.cancel() }; helloTasks.removeAll()
        record("parking", message.map { ["error": $0, "source": "lockWidget"] } ?? ["confirmed": requestedLock, "source": "lockWidget"])
        upload()
        peripheral?.delegate = nil
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil; characteristic = nil
        central?.delegate = nil; central = nil
        if let message { continuation.resume(throwing: Failure(message: message)) }
        else { continuation.resume() }
    }
    private func record(_ kind: String, _ data: [String: Any]) {
        if events.count >= 100 { events.removeFirst() }
        events.append(["session": operation.uuidString, "time": ISO8601DateFormatter().string(from: Date()), "kind": kind, "data": data])
    }
    private func upload() {
        let defaults = UserDefaults.standard
        guard let endpoint = defaults.string(forKey: "scooterWidgetDiagnosticsURL"),
              let url = URL(string: endpoint), url.scheme == "https",
              let token = defaults.string(forKey: "scooterWidgetDiagnosticsToken") else { return }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: events)
        URLSession.shared.dataTask(with: request).resume()
    }
}
