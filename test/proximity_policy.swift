import Foundation

@main
struct ProximityTests {
    static func main() {
        let base = Date(timeIntervalSince1970: 1_000)
        func sample(_ policy: inout ProximityPolicy, _ rssi: Int, _ start: Int, _ end: Int,
                    locked: Bool = false, stationary: Bool = true) -> [Bool] {
            (start...end).compactMap { tick in
                policy.sample(rssi: rssi, stationary: stationary, locked: locked,
                              now: base.addingTimeInterval(Double(tick)))
            }
        }
        var p = ProximityPolicy()
        assert(sample(&p, -85, 0, 10).isEmpty, "Do not lock without observing the owner nearby")
        p = ProximityPolicy()
        assert(sample(&p, -55, 0, 4).isEmpty)
        assert(sample(&p, -85, 5, 9).isEmpty, "Weak signal must persist")
        assert(sample(&p, -85, 10, 10) == [true], "Lock after a sustained departure")
        p.completed(now: base.addingTimeInterval(10))
        assert(sample(&p, -55, 11, 24, locked: true).isEmpty, "Cooldown prevents oscillation")
        assert(sample(&p, -55, 25, 28, locked: true) == [false], "Unlock after a sustained return")

        p = ProximityPolicy()
        _ = sample(&p, -55, 0, 4)
        assert(sample(&p, -90, 5, 20, stationary: false).isEmpty, "Never lock while moving or stale")
        assert(sample(&p, -90, 21, 25).isEmpty, "Require a new stationary dwell")
        assert(sample(&p, -90, 26, 26) == [true])

        p = ProximityPolicy()
        _ = sample(&p, -55, 0, 4)
        _ = sample(&p, -90, 5, 8)
        assert(sample(&p, -70, 9, 9).isEmpty)
        assert(sample(&p, -90, 10, 14).isEmpty, "Middle band resets departure dwell")
        assert(sample(&p, -90, 15, 15) == [true])

        p = ProximityPolicy()
        p.manual(locked: true, now: base)
        assert(sample(&p, -55, 15, 25, locked: true).isEmpty, "Manual locking survives nearby phone")
        p.disconnected()
        assert(sample(&p, -55, 26, 35, locked: true).isEmpty, "Reconnect alone cannot undo manual locking")
        assert(sample(&p, -90, 36, 41, locked: true).isEmpty)
        assert(sample(&p, -55, 42, 45, locked: true) == [false])

        p = ProximityPolicy()
        p.manual(locked: false, now: base)
        assert(sample(&p, -90, 15, 25).isEmpty, "Do not immediately reverse manual unlocking")
        _ = sample(&p, -55, 26, 30)
        assert(sample(&p, -90, 31, 36) == [true])

        for invalid in [127, 0, -127] {
            p = ProximityPolicy(); p.hasDeparted = true
            assert(sample(&p, invalid, 0, 20, locked: true).isEmpty)
        }
        p = ProximityPolicy(); p.hasDeparted = true
        _ = sample(&p, -55, 0, 2, locked: true)
        assert(sample(&p, -55, 10, 12, locked: true).isEmpty, "A suspended gap resets dwell")
        assert(sample(&p, -55, 13, 13, locked: true) == [false])
        print("Proximity policy: departure, arrival, manual override, motion, gaps, invalid RSSI, and cooldown passed")
    }
}
