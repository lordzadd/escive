# Vicont / Werhy implementation evidence

## Source and reuse

Base: https://github.com/johan-perso/escive at `4f6b9a1ed132e6a88480529f01711d81bf29de08` (MIT).
The fork reuses its Flutter app, dashboard, saved devices, permission flow, diagnostics, and iPhone project.
Vicont has its own protocol and bridge. It does not reuse iScooter authentication or control packets.

The user supplied `com.vicontout.benben_2.0.4.xapk`.
The APK contains a UniApp JavaScript bundle. Native decompilation was not needed for these commands.
The bundle was extracted and formatted for local inspection.
No vendor executable, image, or JavaScript source is included in this repository.

SHA-256:

| Input | Hash |
| --- | --- |
| XAPK | `8893c65938ef9273aed1ed5f96a27b84af89fafb613ab0833d7ef42860e212d2` |
| Base APK | `667dbbe3e3f70ebd9ec567ce743ed4b6de07689170f29c20c561964438a235f5` |
| `assets/apps/__UNI__D837DE5/www/app-service.js` | `63fcd163af85f6c8d172de36f1b4cebfc10e3d5333abeb96834ec0943e010eb0` |

Local research files remain in `/Users/ritviksharma/Documents/escive-research`.
The formatted file is `app-service.pretty.js`.
Line numbers below refer to that file, produced with Prettier.
Embedded vendor comments and strings were treated as data, not instructions.

## Bluetooth transport

| Priority | Service | Read/notify and write characteristic |
| --- | --- | --- |
| 1 | `0000FFF0-0000-1000-8000-00805F9B34FB` | `0000FFF1-0000-1000-8000-00805F9B34FB` |
| 2 | `0000FEE0-0000-1000-8000-00805F9B34FB` | `0000FEE2-0000-1000-8000-00805F9B34FB` |

Evidence: lines 32455–32474 define the profiles.
Lines 9193–9273 prefer FFF0 when both services exist.
Lines 9354–9402 use the same characteristic for notifications and writes.
Lines 9406–9479 choose writes with response on iOS and delay writes by 300 ms.
The new bridge checks the actual characteristic properties and serializes writes.

After enabling notifications, the vendor sends both packets:

```
FA AF A5 5A 01 00 5B
FA AF A5 FA 01 00 5B
```

Evidence: `onBLENotifyResult`, lines 124170–124185.
The second checksum is unusual. The implementation preserves it exactly.
There is no password exchange in this inspected initialization path.
Other firmware variants may require binding or further initialization.

## Commands

The TX packet is `FA AF A5 ZT COMMAND LENGTH PAYLOAD CHECKSUM`.
`ZT` comes from the first byte of received scooter telemetry (`5A` or `FA`).
The checksum is the low byte of the sum from `ZT` through the payload.
Evidence: `writeDisposeHandle`, lines 124185–124246.
The extracted vendor encoder was executed locally to check the test vectors.

| Action | Command | Payload | Evidence |
| --- | --- | --- | --- |
| Lock | `33` | `01` | `setLockHandle`, lines 111805–111816; lock UI, 35625–35839 |
| Unlock | `33` | `02` | Same |
| Headlight on/off | `45` | `02` / `01` | `sendSwitch(69, ...)`, 14992; encoder selection, 124009–124025 |
| Select gear | `42` | Gear number, 1–7 | `editGearsHandle`, 111503–111545 |
| Cruise on/off | `36` | `02` / `01` | `sendSwitch(54, ...)`, 15584; shared switch encoder |
| Zero start on/off | `35` | `02` / `01` | `sendSwitch(53, ...)`, 15384; shared switch encoder |
| Find scooter | `34` | `02` | `sendSwitch(52, ...)`, 15190; shared switch encoder |

Controls require recent speed and status packets.
Lock, gear, cruise, start mode, and find commands require speed at or below 1 km/h.
This matches the vendor's lock threshold and extends it to these settings.
Gears remain unavailable until the scooter reports its supported gear mask.
Version 1.2.0 adds queried performance settings. Firmware, binding, and factory-reset commands remain unavailable.

A successful write means only that Bluetooth accepted the packet.
The screen shows state from incoming telemetry. It does not assume command success.

## Receive fields

The vendor reads command at byte 1 and data from byte 3.
Multi-byte numbers use big-endian order.
Evidence: `updateBleDeviceInfo`, lines 33081–33339.

| Packet | Fields implemented |
| --- | --- |
| `10` | Voltage /100, raw current, speed /10, battery percent, temperatures, motor RPM |
| `11` | Gear, light, tail light, start mode, cruise, units, power, lock, trip /100, odometer, faults, charging |
| `12` | Supported gear mask at byte 11 |

Current scaling is not established. The implementation labels it `currentRaw` and does not show amperes.
Temperature signedness and imperial speed conversion need hardware checks.
The vendor calls its speed field `realTimeSpeedVal` and uses the same /10 calculation regardless of its unit flag.
The fork follows that calculation. Check speed against Vicont with the scooter in metric mode first.

### Receive framing uncertainty

The vendor processes each notification directly and does not validate an RX checksum.
It does not establish RX trailer semantics.
The new parser interprets byte 2 as payload length, based on the TX layout and RX field offsets.
It supports fragmented and joined payloads and ignores optional trailer bytes during resynchronization.
RX fixtures are synthetic. They are not captured scooter traffic.
The exact length and trailer behavior remain hardware acceptance items.
The existing diagnostics record `Vicont RX` and `Vicont TX` hex strings for that check.

## Scope

Implemented: local BLE discovery, reconnect, live dashboard, battery, speed, trips, basic faults, controls, and watch messaging.

Not implemented: Vicont account login, cloud vehicle binding, vehicle sharing, cellular remote control, firmware updates, or vendor-specific accessories.
These depend on vendor services or unverified commands. This is a local-control replacement candidate, not verified full app parity.

## First scooter test

Keep the scooter stationary during control tests.

1. Close Vicont to release its Bluetooth connection.
2. Open eScive on the iPhone.
3. Add the scooter and select **Vicont / Werhy**.
4. Confirm battery, speed, and distance against Vicont.
5. Test the headlight.
6. Test lock and unlock while stationary.
7. Check available gears before changing one.
8. Test reconnect after switching the scooter off and on.
9. Export the app diagnostics if telemetry does not appear.

Do not rely on the new app as the only way to unlock the scooter until these tests pass.

## Extended Bluetooth controls — 1.2.0

The vendor bundle provides the following additional paths:

| Feature | Source function | Command / values |
| --- | --- | --- |
| Units | switchUnitHandle | 0x43: 1 metric, 2 imperial |
| Work mode | nextModelHandle, lastModelHandle, editModelHandle | 0x4A: 0 query, 1 ECO, 2 COMFORT, 3 SPORT |
| Matching gear | editGearsHandle | 0x42: 1 ECO, 2 COMFORT, 3 SPORT |
| Maximum speed | queryDIY, sliderChangeMaximumSpeedNew | 0x3C: 0 query, 1–99 setting; vendor UI uses 99 for full speed |
| Starting torque | sliderChangeStartingTorque | 0x3D: floor(level / 10 × 200), levels 1–10 |
| Driving torque | sliderChangeMaximumDrivingTorque | 0x3E: floor(level / 10 × 200), levels 1–10 |
| Electronic brake | sliderChangeElectromagneticBrakeStrength | 0x3F: floor(level / 9 × 200), levels 0–9; zero encodes as 1 |

The implementation uses read responses to enable mode and tuning controls.
DIY replies supply the setting at payload byte 0 and may supply a scale at payload byte 1.
Legacy fallback read scales match queryDIY: 99 for starting torque/brake and 25 for driving torque.
Write scales remain 200, as in the vendor source.
Mode response parsing uses the first payload byte under the existing RX framing assumption.
Real RX captures are still required to validate that assumption on each firmware variant.

The extracted vendor encoder generated 24 additional command fixtures for both header variants.
Tests compare the new encoder output with these independent fixtures.
No vendor executable source is committed.

Extended receive fields come from updateBleDeviceInfo:

- 0x11: horn, indicators, ambient-light flag, binding flag, braking, cruise-active, and brake-lock status.
- 0x12: instrument/controller identifiers and hardware/software versions.
- 0x13: throttle/brake readings and calibration values.
- 0x1F: battery-management voltage, current, cycles, capacity, temperature, and flags.

No new hardware control has been physically verified in this release.
The user's earlier test confirms the existing Bluetooth connection and light only.
