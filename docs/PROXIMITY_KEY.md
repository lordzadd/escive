# Experimental proximity key

Version 1.2.9 (18) adds an optional iPhone proximity key for the selected Vicont scooter.
The dashboard layout is unchanged. Enable the feature in Settings > Scooter key after connecting.
It starts disabled and requests permission for local confirmation notifications when enabled.

## Behavior

- Stand beside the scooter to arm departure locking. Enabling beside an already locked scooter does not unlock it immediately.
- A strong signal (at least -65 dBm) must persist for at least three seconds and four samples.
- A weak signal (at most -80 dBm) must persist for at least five seconds and six samples.
- An intermediate signal, invalid sample, moving scooter, stale telemetry, or sample gap resets the dwell.
- Automatic commands require fresh speed and lock telemetry, exactly zero speed, and matching electronic/brake flags.
- Departure sends the existing APK-derived 0x33/02 command while still connected.
- Return sends 0x33/01 only after an observed departure.
- Fresh electronic and brake feedback must confirm each action. No optimistic lock state or unattended retries.
- A 15-second cooldown prevents rapid reversals.
- Manual phone/widget actions take priority. Manual locking requires a new observed departure before automatic unlocking.
- A dropped connection alone never counts as departure or successful locking.
- Changing the selected scooter disables the feature. Disable it in Settings to stop the native connection.

The thresholds are initial test values, not measured distances. Body position, walls, interference, and phone placement affect RSSI.
This does not provide secure distance verification or relay resistance.

## iOS operation

A separate native CoreBluetooth manager uses state preservation and restoration.
Scooter notifications trigger RSSI requests; background operation does not depend on Flutter timers.
The native monitor subscribes to the same known scooter alongside the dashboard connection.
That coexistence, and scooter behavior while parked, require physical testing.

Keep Bluetooth enabled, keep the scooter powered, and leave the app running in the background.
Do not rely on automatic locking if the connection disappears before the command is sent.
Check the physical P indicator and immobilization during initial tests.
Missing notifications do not establish success; notification permission and iOS execution are required.

Apple documents limits on Bluetooth restoration after force quit, Bluetooth toggles, and restart.
On iOS 26, some relaunch paths require AccessorySetupKit. This build does not add that setup flow.
Reopen eScive after force quitting it or changing Bluetooth settings.

Source: [Apple TN3115](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules).

## Diagnostics and validation

The existing Railway endpoint receives signal samples, connection changes, command bytes, manual overrides, and confirmed/failed outcomes.
No read token is packaged. Native uploads are best effort.

Pure Swift tests cover departure/arrival dwell, motion/stale blocking, middle-band resets, cooldown,
manual lock/unlock overrides, reconnect behavior, invalid RSSI, and suspension gaps.
These tests establish software decisions, not physical lock behavior or background reliability.

Physical acceptance still requires walking away and returning with the phone locked, checking P,
testing a manual lock while nearby, and checking dashboard/widget coexistence.

Validation on 2026-10-13: analysis is clean; the existing 40 Flutter tests pass, with one external test skipped.
The new Settings test passes. The native proximity policy checks and eight APK lock vectors pass.
Device and simulator builds succeed. Simulator installation and launch report version 1.2.9, build 18,
the embedded lock widget, and translated quick-action titles. This is not a physical proximity test.
