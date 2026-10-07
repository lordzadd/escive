# Apple Watch Series 2 companion

The requested watch is MP062ZP/A with reported watchOS 6.3.1.
The companion uses a watchOS 6 dual-target WatchKit app with SwiftUI.
It uses `WatchConnectivity` to send commands to the iPhone.
The iPhone maintains the scooter Bluetooth connection.

The watch shows battery and speed. It provides lock, unlock, and headlight controls.
Commands are immediate messages. Offline commands are not queued.
The phone rejects expired requests, repeated request IDs, and requests for a different scooter.
Controls require current scooter telemetry.
The watch shows **Sent** after a write, rather than claiming the scooter changed state.

Keep eScive active on the iPhone for initial testing.
Background execution and phone wake behavior are not verified.
There is no direct watch-to-scooter Bluetooth connection in this implementation.

## Build configuration

Targets `LegacyWatch` and `LegacyWatchExtension` are in `ios/Runner.xcodeproj`.
The `LegacyWatch` scheme builds the watch app.
The targets use watchOS 6.0 as their minimum version.
Device builds include armv7k for Series 2 and arm64_32 for newer watches.
The phone target does not embed the watch by default.
This keeps the old watch requirement separate from phone builds.

To embed the watch after selecting a suitable signing and deployment environment:

```sh
ruby tools/add_legacy_watch.rb --embed
```

To detach it again:

```sh
ruby tools/add_legacy_watch.rb
```

Set signing teams for all three targets in Xcode.
If you change the phone bundle identifier, update the two watch identifiers and companion references in their plists.
A signing profile and a paired physical watch are required for installation.

## Compatibility boundary

Apple lists Series 2 support through watchOS 6.3:
https://support.apple.com/en-ca/118490

Apple lists Xcode 26.6 device support from watchOS 8:
https://developer.apple.com/xcode/system-requirements

This Mac has Xcode 26.6. Its compiler can produce an `armv7k` watchOS 6 binary.
That does not prove its deployment tools can install the app on Series 2.
An older compatible Xcode environment or a separately verified installation path is still required.
A newer iPhone OS can further restrict which older Xcode environment works.
Do not assume that changing the deployment target alone solves installation.

See `VALIDATION.md` for the exact build results.
