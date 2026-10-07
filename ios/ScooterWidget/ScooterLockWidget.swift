import SwiftUI
import WidgetKit
import AppIntents

struct LockEntry: TimelineEntry { let date: Date }
struct LockProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockEntry { LockEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (LockEntry) -> Void) { completion(LockEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockEntry>) -> Void) {
        completion(Timeline(entries: [LockEntry(date: Date())], policy: .never))
    }
}

@main
struct ScooterLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScooterLock", provider: LockProvider()) { _ in
            Button(intent: ToggleScooterLockIntent()) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lock or unlock scooter")
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Scooter lock")
        .description("Lock or unlock using the scooter's current state. Connect in eScive once before use.")
        .supportedFamilies([.accessoryCircular])
    }
}
