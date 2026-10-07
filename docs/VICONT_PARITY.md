# Vicont feature parity audit — 2026-10-07

## Current model assessment: 039ZQ-31

The user identifies the scooter as model 039ZQ-31.
The manufacturer's 039ZQ control-kit manual covers the family, but does not explain the -31 suffix.
Do not infer the vendor's modelId or versionType from this number.
The extracted APK contains no matching 039ZQ model string.
Its getFunctionList request uses a server-provided modelId.

Source: [Vicont 039ZQ manual, pages 4 and 8](https://device.report/m/268d2c5457d7c17565c8cce882acefb5b4b389a95d1747f50558593215e14b72_optim.pdf).

| Relevant function | Family evidence | Current 1.2.3 status |
| --- | --- | --- |
| Parking lock | Manual describes P indication and movement alarms; user confirms Vicont immobilizes this scooter | Corrected APK main-screen command is implemented; physical acceptance remains pending |
| Lights | Manual describes front/rear light control | Headlight works according to the user; rear-light behavior remains unverified |
| Three gears | Manual lists three gears | Selection uses the device's advertised gears; physical acceptance remains pending |
| Speed adjustment | Manual explicitly allows third-gear speed adjustment through the app | Speed tuning is implemented when the scooter answers its query; effect remains unverified |
| Battery display | Manual describes the dashboard battery indicator | App telemetry is implemented; accuracy comparison remains pending |
| Firmware updates | Manual advertises OTA support | No update implementation; no available firmware or exact -31 support established |

Cruise, zero-start, find, units, ride modes, diagnostics, and torque/brake tuning exist in our app.
The shared APK supports these paths, but the manual does not establish every option for the -31 variant.
No inspected model-specific evidence establishes saddle, helmet, or basket accessories on this scooter.
Do not count these generic APK features as required parity gaps.
Maps, cellular control, and account services also lack evidence as required functions for this scooter.

Conclusion: core controls are implemented, but working parity is not yet established.
The main unresolved acceptance item is physical P locking and unlocking with version 1.2.3.
The model number does not resolve the APK's versionType-dependent binding branch.
No UI or protocol change follows from the model number alone.
This update uses document and source inspection; it adds no automated or physical test result.

The sections below retain the earlier generic audit and release history.

## Requirement and device evidence

The user requires feature parity with Vicont, beyond basic Bluetooth controls.
The user confirms that Bluetooth connection and the light work in version 1.1.2.
The user clarifies that parking means locking the scooter, not saving its location or a separate P mode.
Physical locking has not yet been reported as working.

Version 1.2.0 exposes this function as direct Lock / Unlock buttons under Parking lock.
The corrected main-screen mapping uses 0x33 with 02 for lock and 01 for unlock.
See APK_LOCK_TRACE.md for the corrected main-screen trace and the separate instrument-panel path.
This must not be confused with the separate accessory brake-lock command 0x3A.

## Why the interface is sparse

The implementation initially covered a limited set of local Bluetooth controls.
The dashboard retains the upstream eScive layout.
Gear, find, cruise, and zero-start controls sit inside the collapsed Scooter settings section.
Only a subset of received diagnostic fields is visible.
This does not meet full Vicont parity.

## Coverage matrix (updated for 1.2.0)

| Feature | Current fork | Source evidence / remaining work |
| --- | --- | --- |
| Bluetooth connection | User confirms working | Reconnection still needs physical testing |
| Headlight | User confirms working | Existing command 0x45 |
| Parking / electronic lock | Implemented as direct buttons | Command 0x33; physical effect needs testing |
| Find scooter | Implemented | Command 0x34; physical sound unverified |
| Gear selection | Implemented when advertised | Command 0x42; available-gear mask from packet 0x12 |
| Cruise control | Implemented | Command 0x36; device operation unverified |
| Zero-start | Implemented | Command 0x35; device operation unverified |
| Speed, battery, trip, odometer | Implemented | Compare values with Vicont on the device |
| Voltage and temperatures | Detailed display | Voltage, all three temperatures, and motor RPM are shown |
| Device unit setting | Implemented | Vendor `switchUnitHandle` sends command 0x43 |
| ECO / SPORT / COMFORT modes | Implemented after query response | Vendor queries/sets command 0x4A and also changes gear; preserve the vendor mapping |
| Detailed operating status | Implemented | Packet 0x11 contains braking, cruise-active, lock-condition, charging, and accessory flags |
| Fault diagnostics | Ten named faults | Fault bits and descriptions are decoded separately from operating status |
| Battery diagnostics | Implemented when reported | Vendor decodes additional BMS data beyond the current 0x10/0x11/0x12 subset |
| Hardware/software versions | Implemented | Vendor decodes version fields in packet 0x12 |
| Speed/torque/brake tuning | Implemented after query response | Vendor DIY commands 0x3C–0x3F; writes require stationary state and read back the setting |
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

## 1.2.0 implementation notes

The earlier sparse-interface section describes 1.1.2.
Version 1.2.0 opens the scooter controls by default and replaces the Vicont slider with direct parking-lock buttons.
It preserves the main speedometer and upstream trip display.

Modes use 0x4A values 1 (ECO), 2 (COMFORT), and 3 (SPORT), with matching gear commands.
Modes require a valid query response and an advertised matching gear.
Units use 0x43 values 1 (metric) and 2 (imperial).
The unit switch changes the scooter display setting, not the app's independent display preferences.

Tuning queries use zero payloads for commands 0x3C–0x3F.
The application never enables tuning from cached capabilities.
Speed accepts 1–99, torque accepts levels 1–10, and electronic brake accepts levels 0–9.
Torque writes use level × 20. Brake writes use floor(level / 9 × 200), with level zero encoded as 1.
These mappings follow the inspected vendor controls.
After writing, the app queries again and displays the returned value. A write alone does not confirm application.
Zero acknowledgements do not enable tuning. Disconnect clears queried settings.

The new parser displays packet 0x13 sensor values and packet 0x1F battery-management data when reported.
Battery capacity fields remain raw because their units are not established.
The vendor source overlaps the battery ID and flag byte; the implementation preserves that layout.
Battery diagnostics and imperial speed interpretation require manual comparison with Vicont.

This is expanded local Bluetooth coverage, not complete Vicont parity.
Cloud account services, binding/sharing, cellular control, firmware updates, ambient-light configuration,
accessory actions, and exact vendor trip synchronization remain missing.
The shared vendor bundle does not establish this scooter model's accessory support.

The current 1.2.3 build retains the restored 1.1.2 dashboard. Historical layout descriptions above apply to 1.2.0.
