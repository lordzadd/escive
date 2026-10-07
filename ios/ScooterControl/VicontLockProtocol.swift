import Foundation

// Mirrors lib/protocols/vicont.dart and the executed APK lock vectors.
struct VicontLockProtocol {
    private var buffer: [UInt8] = []
    private(set) var header: UInt8?
    private(set) var speed: Double?
    private(set) var speedAt: Date?
    private(set) var statusAt: Date?
    private(set) var electronic = false
    private(set) var brake = false

    static func lockPacket(_ header: UInt8, locked: Bool) -> [UInt8] {
        let body: [UInt8] = [header, 0x33, 1, locked ? 2 : 1]
        return [0xfa, 0xaf, 0xa5] + body + [body.reduce(0, &+)]
    }

    mutating func receive(_ bytes: [UInt8], now: Date = Date()) {
        buffer += bytes
        while buffer.count >= 3 {
            let code = Int(buffer[1])
            guard [0x5a, 0xfa].contains(buffer[0]), buffer[2] <= 64,
                  [1, 16, 17, 18, 19, 20, 31].contains(code) || (51...76).contains(code) else {
                buffer.removeFirst(); continue
            }
            let size = Int(buffer[2]) + 3
            guard buffer.count >= size else { break }
            let p = Array(buffer.prefix(size)); buffer.removeFirst(size)
            if code == 0x10, p.count >= 15, p[9] <= 100 {
                speed = Double(Int(p[7]) * 256 + Int(p[8])) / 10
                speedAt = now; header = p[0]
            }
            if code == 0x11, p.count >= 13 {
                electronic = p[4] & 2 != 0
                brake = p[11] & 4 != 0
                statusAt = now; header = p[0]
            }
        }
    }

    func toggleTarget(now: Date = Date()) -> Bool? {
        guard fresh(now: now), let speed, speed <= 1, electronic == brake else { return nil }
        return !brake
    }

    func confirmed(_ locked: Bool, after: Date, now: Date = Date()) -> Bool {
        guard fresh(now: now), let statusAt, statusAt > after else { return false }
        return electronic == locked && brake == locked
    }

    func fresh(now: Date = Date()) -> Bool {
        guard let speedAt, let statusAt else { return false }
        return now.timeIntervalSince(speedAt) < 2 && now.timeIntervalSince(statusAt) < 2
    }
}
