import Foundation

@main
struct WidgetProtocolChecks {
    static func main() throws {
        let rows = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "test/vicont_lock_main_screen_vectors.json"))) as! [[String: Any]]
        for row in rows {
            let header = UInt8(row["header"] as! String, radix: 16)!
            let bytes = VicontLockProtocol.lockPacket(header, locked: row["currentElectronicLock"] as! Int == 0)
            precondition(bytes.map { String(format: "%02x", $0) }.joined() == row["hex"] as! String)
        }
        let now = Date()
        let speed: [UInt8] = [90,16,12,16,104,0,12,0,0,75,30,31,32,3,232]
        let unlocked: [UInt8] = [90,17,10,1,1,0,0,0,0,0,0,0,0]
        let locked: [UInt8] = [90,17,10,1,3,0,0,0,0,0,0,4,0]
        var decoder = VicontLockProtocol()
        decoder.receive([0, 255] + Array(speed.prefix(8)), now: now)
        precondition(!decoder.fresh(now: now))
        decoder.receive(Array(speed.dropFirst(8)) + unlocked, now: now)
        precondition(decoder.toggleTarget(now: now) == true)
        precondition(!decoder.confirmed(false, after: now, now: now))
        precondition(decoder.toggleTarget(now: now.addingTimeInterval(3)) == nil)
        decoder.receive(locked, now: now.addingTimeInterval(0.5))
        precondition(decoder.toggleTarget(now: now.addingTimeInterval(0.5)) == false)
        precondition(decoder.confirmed(true, after: now, now: now.addingTimeInterval(0.5)))
        var transitional = locked; transitional[11] = 0
        decoder.receive(transitional, now: now.addingTimeInterval(0.6))
        precondition(decoder.toggleTarget(now: now.addingTimeInterval(0.6)) == nil)
        precondition(!decoder.confirmed(true, after: now, now: now.addingTimeInterval(0.6)))
        var moving = speed; moving[8] = 20
        decoder.receive(moving + unlocked, now: now)
        precondition(decoder.toggleTarget(now: now) == nil)
        print("PASS: 8 APK packet fixtures; split RX; fresh-state toggle; stale, moving, transitional and post-command feedback checks")
    }
}
