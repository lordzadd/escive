import Foundation

// RSSI is a coarse signal measurement, not a distance or identity proof.
struct ProximityPolicy {
    var hasDeparted = false
    var hasBeenNear = false
    var manualLock = false
    private var candidate: Bool?
    private var since: Date?
    private var previous: Date?
    private var count = 0
    private var blockedUntil = Date.distantPast

    mutating func resetSamples() {
        candidate = nil; since = nil; previous = nil; count = 0
    }

    mutating func disconnected() {
        // A radio interruption is not evidence that the owner walked away.
        hasBeenNear = false
        resetSamples()
    }

    mutating func manual(locked: Bool, now: Date) {
        manualLock = locked
        hasBeenNear = false; hasDeparted = false
        blockedUntil = now.addingTimeInterval(15)
        resetSamples()
    }

    mutating func completed(now: Date) {
        blockedUntil = now.addingTimeInterval(15)
        resetSamples()
    }

    mutating func sample(rssi: Int, stationary: Bool, locked: Bool, now: Date) -> Bool? {
        guard (-110 ... -15).contains(rssi), stationary, now >= blockedUntil else {
            resetSamples(); return nil
        }
        let near: Bool
        if rssi >= -65 { near = true }
        else if rssi <= -80 { near = false }
        else { resetSamples(); return nil }
        if let previous, now.timeIntervalSince(previous) < 0.8 { return nil }
        if candidate != near || previous.map({ now.timeIntervalSince($0) > 3 }) == true {
            resetSamples(); candidate = near; since = now
        }
        previous = now; count += 1
        guard let since, count >= (near ? 4 : 6),
              now.timeIntervalSince(since) >= (near ? 3 : 5) else { return nil }
        if near {
            hasBeenNear = true
            if locked && hasDeparted && !manualLock { return false }
        } else {
            hasDeparted = true; manualLock = false
            if !locked && hasBeenNear { return true }
        }
        return nil
    }
}
