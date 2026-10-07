# Vicont feature parity audit — 2026-10-06

## Requirement and device evidence

The user requires feature parity with Vicont, beyond basic Bluetooth controls.
The user confirms that Bluetooth connection and the light work in version 1.1.2.
The user clarifies that parking means locking the scooter, not saving its location or a separate P mode.
Physical locking has not yet been reported as working.

The current app exposes this function as Slide to Lock / Slide to Unlock.
It sends Vicont command 0x33 with 01 for lock and 02 for unlock.
The inspected vendor function `setLockHandle` sends the same command.
This must not be confused with the separate accessory brake-lock command 0x3A.

## Why the interface is sparse

The implementation initially covered a limited set of local Bluetooth controls.
The dashboard retains the upstream eScive layout.
Gear, find, cruise, and zero-start controls sit inside the collapsed Scooter settings section.
Only a subset of received diagnostic fields is visible.
This does not meet full Vicont parity.

## Coverage matrix

| Feature | Current fork | Source evidence / remaining work |
| --- | --- | --- |
| Bluetooth connection | User confirms working | Reconnection still needs physical testing |
| Headlight | User confirms working | Existing command 0x45 |
| Parking / electronic lock | Implemented as lock slider | Command 0x33; physical effect and gesture need testing |
| Find scooter | Implemented | Command 0x34; physical sound unverified |
| Gear selection | Implemented when advertised | Command 0x42; available-gear mask from packet 0x12 |
| Cruise control | Implemented | Command 0x36; device operation unverified |
| Zero-start | Implemented | Command 0x35; device operation unverified |
| Speed, battery, trip, odometer | Implemented | Compare values with Vicont on the device |
| Voltage and temperatures | Partial display | Controller temperature and motor RPM are parsed but not shown |
| Device unit setting | Missing | Vendor `switchUnitHandle` sends command 0x43 |
| ECO / SPORT / COMFORT modes | Missing as distinct work modes | Vendor queries/sets command 0x4A and also changes gear; preserve the vendor mapping |
| Detailed operating status | Partial | Packet 0x11 contains braking, cruise-active, lock-condition, charging, and accessory flags |
| Fault diagnostics | Raw fault number only | Need individual fault descriptions and status display |
| Battery diagnostics | Missing | Vendor decodes additional BMS data beyond the current 0x10/0x11/0x12 subset |
| Hardware/software versions | Missing | Vendor decodes version fields in packet 0x12 |
| Speed/torque/brake tuning | Missing | Vendor DIY page uses commands 0x3C–0x3F; must trace model support, ranges, query responses, and confirmation |
| Accessory locks | Missing | Vendor handles saddle, helmet, basket, and brake locks separately; hardware/model dependent |
| Saved parking location/navigation | Not established as equivalent | Not the parking function requested here |
| Trips and ride history | Upstream implementation only | Vicont-equivalent recording and accuracy remain unverified |
| Account, binding, sharing, cellular control | Missing | Vendor service integration, separate from local BLE |
| Firmware updates | Missing | Requires a separate verified update path |
| Watch controls | Experimental, separate app | Not part of the delivered phone IPA; installation/runtime remain unverified |

## Source basis

This audit uses the user-supplied Vicont 2.0.4 bundle already recorded in VICONT_PROTOCOL.md.
The source stays outside this repository.
Relevant functions include `setLockHandle`, `switchUnitHandle`, `nextModelHandle`, `lastModelHandle`, `updateBleDeviceInfo`, and `getFunctionList`.
The vendor gets the feature list using the vehicle model ID.
A command in the shared vendor bundle does not prove that this Werhy model supports it.
The separate brake-lock handler is therefore not evidence for adding a second parking control.

## Implementation priorities

1. Make existing controls easy to find and name the electronic lock clearly.
2. Expose supported live telemetry, fault descriptions, and version information.
3. Match unit settings and ride modes, including their response handling.
4. Trace model-specific tuning and accessory capabilities before exposing their controls.
5. Track cloud features and firmware separately until their dependencies are established.

Every feature needs a source-backed protocol check, a UI check, and a separate physical acceptance result.
Do not treat a successful Bluetooth write as confirmation that the scooter applied the command.
