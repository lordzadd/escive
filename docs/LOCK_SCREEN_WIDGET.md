# Lock Screen scooter button

Version 1.2.7 adds one circular interactive widget for iOS 17 or later.
Tap it to read the scooter's current state, then request the opposite state.
It does not infer the action from cached widget data.
The dashboard layout remains unchanged.

## Installation

Sign and install the IPA with Signulous, including its embedded ScooterLockWidget extension.
Open eScive and connect the intended Vicont scooter once.
This saves the selected iOS Bluetooth identifier in the host app.
Customize the iPhone Lock Screen, choose Add Widgets, then eScive and Scooter lock.
The scooter must be on and nearby.
iOS requires authentication before an interactive Lock Screen widget performs its action.
The action runs in the app process without opening its interface.

## Implementation

The WidgetKit button uses a shared App Intent with LiveActivityIntent conformance.
Apple documents that this conformance runs the intent in the host app process.
The host uses CoreBluetooth and its saved peripheral identifier; no App Group is required.
The app enables bluetooth-central background mode.
The widget has no cloud dependency. Diagnostics upload is best effort and does not determine command success.

The native protocol matches the existing Dart implementation:

- Discover FFF0/FFF1 or FEE0/FEE2.
- Enable notifications and use the two vendor hello packets.
- Require fresh speed and status, with speed at most 1 km/h.
- Wait for electronic and brake lock flags to agree before choosing the opposite state.
- Send 0x33/02 for lock or 0x33/01 for unlock, using the received header.
- Require post-command status with both flags matching the requested state.
- Stop on timeout, Bluetooth failure, movement, or disconnection.
- Reject overlapping requests. Never send binding or accessory-lock commands.

The static icon identifies the action. It does not claim to display live lock status.
The intent reports success only after scooter feedback. Physical P and wheel behavior still require a device check.
The native path has a 15-second timeout and sends source=lockWidget diagnostic events.
It does not retry failed commands automatically.

## Validation

Compile and run the native protocol checks from the repository root:

```
swiftc ios/ScooterControl/VicontLockProtocol.swift test/vicont_widget_protocol.swift -o /tmp/escive-widget-protocol
/tmp/escive-widget-protocol
```

These verify all eight APK-derived packets, fragmented status, stale data, movement,
transitional flags, both toggle directions, and post-command confirmation.
Automated checks cannot establish Signulous extension preservation, background execution,
or Bluetooth behavior on the physical phone. Test both directions from the Lock Screen after installation.

Reference: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
