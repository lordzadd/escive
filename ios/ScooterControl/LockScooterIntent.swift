import AppIntents
import Foundation

@available(iOS 17.0, *)
struct ToggleScooterLockIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Lock or unlock scooter"
    static var description = IntentDescription("Read the current scooter state, then lock or unlock it over Bluetooth.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if SCOOTER_WIDGET_EXTENSION
        return try unavailable()
        #else
        try await ScooterLocker.shared.toggleLock()
        return .result(dialog: "Scooter lock state changed and confirmed.")
        #endif
    }
    private func unavailable() throws -> some IntentResult & ProvidesDialog {
        throw IntentFailure()
        return .result(dialog: "Open eScive once to set up the widget.")
    }
}

private struct IntentFailure: LocalizedError {
    var errorDescription: String? { "Open eScive once to set up the lock widget." }
}
