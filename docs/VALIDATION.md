# Validation — 2026-10-06

## Confirmed

- Repository cloned at `4f6b9a1ed132e6a88480529f01711d81bf29de08`.
- Work branch: `feat/vicont-werhy-watch`.
- Local vendor bundle inspected for profiles, initialization, encoding, controls, and telemetry.
- Vendor encoder run against 14 command vectors across both header variants.
- Protocol and disconnected-panel tests pass: 13 tests.
- Flutter analysis passes with no findings.
- Flutter debug application bundle builds.
- Unsigned iPhone release builds successfully: `build/ios/iphoneos/Runner.app` (71.1 MB).
- Unsigned IPA packaging passes ZIP integrity validation: `build/ios/ipa/eScive-Werhy-unsigned.ipa` (about 27 MB).
- iPhone Swift entry point and watch bridge pass native type checking with the actual Flutter framework and generated bridging header.
- Full unsigned WatchKit app and extension build for `armv7k` and `arm64_32`.
- Watch storyboard compiles and the embedded extension passes Xcode validation.

The unsigned watch app is `ios/build/Debug-watchos/LegacyWatch.app`.
It is not an installed or signed application.

## Upstream issues fixed

The first dependency resolution failed because Flutter 3.29 pins `intl` to 0.19.0.
The fork aligns its dependency and records the resolved dependency lock files.
The iOS brightness plugin resolved to 2.1.4 and required newer Flutter scene APIs.
The fork pins its compatible iOS implementation to 2.1.2.
The publisher records the scene lifecycle change in version 2.1.3:
https://pub.dev/packages/screen_brightness_ios/changelog

The baseline analyzer found three `RadioGroup` errors and one library-name notice.
The selector now uses the Radio API available in Flutter 3.29.

Duplicate device names could throw during integer parsing.
They now receive a numeric suffix.
The device scan now owns and cancels its subscription.
Scan errors no longer access an uninitialized timer.
The protocol chooser can be cancelled without disabling further actions.

Speed readers now accept decimal values from Vicont.
The existing integer cast would crash on the first decimal speed update.

## Not established

- No physical Werhy scooter connection or captured RX packet fixture.
- No physical command acknowledgement or movement test.
- No signed iPhone installation.
- No Apple Watch Series 2 installation or runtime test.
- No verified background control while the phone app is suspended.
- No complete Vicont cloud-service replacement.

## Build environment

Flutter 3.29.1, Dart 3.7.0, Xcode 26.6.
An initial Xcode framework load error was resolved with `xcodebuild -runFirstLaunch`.
The iPhone build then stopped because Xcode lacked the iOS 26.5 platform.
The iOS 26.5 platform was downloaded and installed successfully.
The release build succeeds after pinning the brightness plugin.
The iOS 26.5 simulator build also succeeds.
The app was installed and launched in a separate QA simulator.
Its welcome screen rendered correctly, including the Bluetooth access control.
Screenshot: `/Users/ritviksharma/Documents/escive-research/iphone-startup.png`.
This checks startup only. It does not test physical Bluetooth access or scooter controls.

IPA SHA-256: `263c8ff46b4fe3c125999f6fc693956aa6bd52d2be4a9a37377333c7d065b398`.
The IPA contains the release phone app without the legacy watch target.
The watch app remains available as a separate unsigned build.

Build and research logs are outside the repository in `/Users/ritviksharma/Documents/escive-research`.
The complete APK and vendor source stay outside the repository as well.

## Control refresh fix — 1.1.1+7

The first physical test reports a Bluetooth connection but disabled controls.
The screenshots show received battery and distance values alongside a stale control panel.
A widget regression reproduces the panel remaining disabled after connection.
The constant stateless panel reads mutable global state without subscribing to updates.
It now owns a refresh subscription and cancels it when removed.

The dashboard restores the original lock slider and light switch for Vicont.
Additional settings move into a collapsible section.
The lock slider does not show a success animation merely because a write completes.
Fresh telemetry and stationary checks remain enforced.
The packet parser and Bluetooth command encoding are unchanged.

The regression verifies connection, command dispatch, received light state, moving-state restrictions, and disconnection.
All 14 tests pass. Static analysis reports no issues.
Hardware command execution still requires another scooter test.

The unsigned iPhone release build succeeds.
The versioned IPA passes archive validation and contains version 1.1.1, build 7.
IPA: `build/ios/ipa/eScive-Werhy-1.1.1-unsigned.ipa`.
SHA-256: `07ea35f6e9429fb998af100bfab73f5d53ac0cbacd01c251c666e8eb754d5f33`.

## Expanded QA — 2026-10-06

Release status: HOLD. No new IPA was created during this pass.
The existing 1.1.1+7 IPA remains unchanged, with the SHA-256 listed above.
It does not include the fixes from this pass.

### Automated coverage

All 24 Flutter tests pass. Static analysis reports no issues.
The new tests replace the native Bluetooth boundary with synthetic responses.
They exercise the actual Dart Bluetooth library, Vicont bridge, parser, and control panel.
The responses are generated fixtures, not recordings from the physical scooter.

- FFF0 and FEE0 discovery, notification subscription, and initialization.
- Writes with response and writes without response.
- Lock, unlock, light, gear, cruise, zero-start, and find command bytes.
- Received battery, distance, available gears, and control state.
- Moving-state restrictions, invalid gears, busy writes, and failed writes.
- Disconnect, reconnect, and automatic reconnect readiness.
- Unsupported services, stale telemetry, and incomplete speed-only telemetry.
- Warning indicators update without sending Bluetooth commands.
- Watch channel dispatch for lock, unlock, and both light states.
- Watch rejection of unknown actions, wrong device IDs, and unavailable connections.

### Simulator checks

A dedicated iPhone 17 Pro simulator runs iOS 26.5.
The normal debug app builds, installs, and displays its Home Screen icon.
The native simulator cannot establish a physical scooter Bluetooth connection.
The debug-only `tool/qa_simulator.dart` runs the production interface with simulated Bluetooth responses.
The release entry point does not import this simulator.

Verified through the interface:

- Welcome screen, device scan, protocol selection, and dashboard navigation.
- A cancelled protocol dialog can be opened again.
- Saved scooter selection survives a hot restart and reconnects.
- Received battery, speed, voltage, temperatures, and distances render.
- Light, gear, cruise, and zero-start controls send commands and reflect subsequent simulated telemetry.
- Find sends the expected command. No physical beep is claimed.
- Double-tapping the lock control sends lock/unlock and updates its label after simulated telemetry.
- The sheet and scooter settings section expand.
- Application settings open and return to the dashboard.
- The inactive-warning setting changes, and the speedometer limit selector opens and accepts a selection.

### Defects fixed during this pass

The full dashboard called a missing `VicontBridge.setWarningLight` method.
This caused repeated runtime errors when telemetry reached warning indicators.
The bridge now emits the expected warning event. A regression test covers the event and rendered indicator.

Unavailable phone battery readings caused unhandled platform errors in the simulator.
Both initial and subsequent reads now log the failure and keep the app running.

Cancelling protocol selection left the scan label showing connection progress.
The selector now clears this label before opening.
The label fix has source review coverage; its exact text still needs a fresh simulator check.

### Remaining release checks

- Horizontal dragging of the lock slider did not trigger a command through the UI automation tool.
  Double-tapping works. The cause remains unresolved: gesture injection or the slider itself.
- No physical scooter command execution, acknowledgement, motion, or reconnection test was performed here.
- No signed installation through Signulous was performed here.
- No physical Watch Series 2 installation, native WatchConnectivity session, or suspended-phone test was performed.
- The IPA has no embedded watch app or widget extension.
- Maps, navigation, music, weather, ride-history accuracy, and all orientation/language combinations are outside this pass.

These limits prevent a full end-to-end release pass. Passing synthetic tests does not remove them.

### Reproduction and evidence

Run `flutter test` and `flutter analyze` from the repository.
For interface testing, run `flutter run -d <simulator-id> -t tool/qa_simulator.dart`.
Never package this QA entry point for distribution.

Local evidence is under `/Users/ritviksharma/Documents/escive-research`:

- `qa-final-tests.txt`: final 24-test pass.
- `qa-final-analyze.txt`: clean static analysis.
- `qa-simulator-build.txt`: simulator build result.
- `qa-simulator-fixed.txt`: simulator session; earlier segments include errors before the fixes.
- `qa-home-icon.png`: installed application icon.
- `qa-controls.png`: expanded dashboard with simulated telemetry.

### Home Screen placement

The app includes an icon and opens from that icon in the simulator.
iOS can place new apps in the App Library only.
The user controls this through Settings > Home Screen & App Library.
Apple documents both installation choices and moving an existing app to the Home Screen:
https://support.apple.com/en-us/108324

## Manual-test IPA — 1.1.2+8

The user requested an IPA and accepted manual device testing for the remaining checks.
This supersedes the packaging hold above, but does not change the hardware verification status.

The production entry point `lib/main.dart` builds successfully for iPhone in release mode.
The debug scooter simulator is not the build target.
The archive passes ZIP integrity validation.
Its Info.plist confirms version 1.1.2, build 8, and the iPhoneOS platform.
The IPA contains the phone app, without the separate legacy watch app.

Artifact: `build/ios/ipa/eScive-Werhy-1.1.2-unsigned.ipa` (26.8 MiB).
SHA-256: `fd821697cc8872c3faf360e6c0abc4d10b378e681acedcf3ed088b7e664f1071`.
Build log: `/Users/ritviksharma/Documents/escive-research/build-1.1.2-release.txt`.

Signulous must sign this unsigned IPA before installation.
The 24-test pass and clean analysis from the preceding QA pass apply to the same application logic.
Only the application version and documentation changed for this packaging step.
Physical controls, the slider gesture, and Watch operation remain manual test items.

## User device feedback — 1.1.2

The user reports that Bluetooth connection and the light work.
This is user-reported physical evidence, distinct from the synthetic test results above.
The user requires Vicont feature parity and clarifies that parking means the electronic scooter lock.
See VICONT_PARITY.md for the current gaps and source-backed feature inventory.
Locking and the other device controls remain unconfirmed.

## Expanded Bluetooth release — 1.2.0+9

The user requested implementation and a new IPA for manual testing.
Added direct parking-lock buttons, expanded controls, mode/unit settings, queried tuning,
named faults, live diagnostic fields, battery details, and device versions.
The Vicont dashboard no longer depends on the previously unverified slider gesture.
Other scooter bridges keep their existing controls.

Thirty automated tests pass. Static analysis reports no issues.
New checks cover 24 independently generated vendor packet vectors, setting queries and readback,
zero acknowledgements, tuning ranges, movement rejection, disconnect cleanup, diagnostic decoding,
and a phone-sized settings dialog with expanded diagnostics.
Test fixtures use synthetic Bluetooth traffic. They do not prove physical device behavior.

Source: docs/VICONT_PROTOCOL.md and docs/VICONT_PARITY.md.
Logs: parity-final-tests.txt, parity-final-analyze.txt, and build-1.2.0-release.txt
under /Users/ritviksharma/Documents/escive-research.

The production entry point is lib/main.dart.
The IPA is for Signulous signing and manual iPhone testing.
Cloud services, firmware updates, accessories, and the separate Watch app are not included.
This release is expanded Bluetooth coverage, not complete Vicont parity.

Release build and IPA archive integrity checks pass.
Artifact: `build/ios/ipa/eScive-Werhy-1.2.0-unsigned.ipa`.
SHA-256: `24c1296ae6bbb4e9e9ca94ef1a4ca8443804f28aaf8641ade8fa924b3f12b2fa`.
Info.plist confirms version 1.2.0, build 9, and iPhoneOS.

## Layout restoration and failed lock report

The user reports that locking does not work in 1.2.0 and objects to repeated layout changes.
The source now restores the exact HomeScreen layout from 1.1.2.
The original lock slider and light switch return. Additional features remain inside Scooter settings.
Static analysis passes. This restoration has not yet been packaged as an IPA.

The lock failure remains unresolved. Do not count command-vector tests as physical acceptance.
The user suggests the Vicont control may be named parking brake.
The inspected bundle contains electronic-lock command 0x33 and a separate brake-lock handler for 0x3A.
Neither the label nor shared source alone establishes which control this model uses.
The next evidence needed is the exact Vicont control label/screen and the observed result when eScive sends Lock.
Do not change the dashboard layout again as part of protocol work.

### Physical parking behavior clarified

The user reports that our app shows locked without immobilizing the scooter.
Vicont locking displays P on the scooter and prevents movement.
This invalidates treating the electronic-lock flag alone as physical parking confirmation.

Further source inspection identifies a model-dependent follow-up in updateBleDeviceInfo.
When deviceInfo.versionType equals 1, Vicont sends command 0x4C with 01 when
lockCarState is 1 and bluetoothBindingStatus is 0; it sends 02 for the opposite mismatch.
Our bridge does not implement this follow-up.
This is a candidate cause, not a confirmed diagnosis for this scooter.
Do not send 0x4C or substitute the accessory command 0x3A without matching model/state evidence.
The current 1.2.0 Live diagnostics section exposes Parking lock, Brake lock, and Bluetooth binding
for comparing Vicont's physical P state against the failed eScive lock attempt.

## Alternate brake-lock test — 1.2.1+10

The user explicitly requested an IPA using the alternate lock command for a physical test.
This authorizes the experiment; it does not establish hardware compatibility.

The existing lock action now sends command 0x3A instead of 0x33.
Payload 02 requests activation and 01 requests release, following the shared sendSwitch(58, currentState) mapping.
The vendor's handler resets its local brake flag after three seconds.
It does not prove that this command provides persistent parking on this model.
No binding notification (0x4C) is added.

The app's locked indicator now follows the reported brake-lock bit in packet 0x11, byte 11, bit 2.
It preserves the separate electronic-lock bit as electronicLocked for diagnostics.
A regression test verifies that an electronic-lock bit alone does not show parking lock.
No status is changed merely because the app sends a command.

The original 1.1.2 dashboard layout is restored, including the lock slider and light switch.
Additional features stay in the collapsed Scooter settings section.
The user will check whether the scooter displays P and prevents movement.
The user should keep Vicont available to release the scooter if the experimental route fails.

All 31 tests pass. Static analysis has no findings.
The production iPhone release build and IPA integrity checks pass.
Artifact: `build/ios/ipa/eScive-Werhy-1.2.1-brake-test-unsigned.ipa`.
Version 1.2.1, build 10. SHA-256: `8b94a99145cad7bc84701236695a11859163d1a8d115c42890a9fe00f84ffa4d`.
This is an experimental phone-only build for Signulous, not a verified physical parking fix.

## Conditional lock-sequence test — 1.2.2+11

The user reports that the alternate 0x3A brake-lock experiment failed.
Screenshots after using Vicont show electronic lock and brake lock changing together.
The user also reports Bluetooth binding on in the parked state.
The unlocked binding state is not established by that report.

This release removes the failed 0x3A experiment from the lock action.
It tests the sequence found in Vicont's versionType=1 path:

1. Send 0x33 with 01 for lock or 02 for unlock.
2. Require fresh telemetry that confirms the requested electronic-lock state.
3. If binding differs from that state, send 0x4C with 01 or 02 respectively.
4. Require matching electronic-lock, brake-lock, and binding feedback.

The scooter's exact versionType remains unknown. This is a source-backed experiment, not a proven model match.
Binding is not changed on connection or unsolicited telemetry.
The operation requires fresh stationary telemetry and blocks overlapping commands.
Timeouts, write errors, and disconnects do not report success.
A binding flag alone does not confirm parking. Physical P and immobilization still require manual testing.
The layout is unchanged from the restored 1.1.2 dashboard.

Synthetic tests cover both Bluetooth profiles, the lock and unlock sequence,
missing electronic feedback, missing brake feedback, already matching binding, and disconnect cancellation.
The real-device screenshots are evidence about displayed status, not command captures.

All 35 tests pass. Static analysis reports no issues.
Release build and IPA archive checks pass.
Artifact: `build/ios/ipa/eScive-Werhy-1.2.2-lock-sequence-test-unsigned.ipa` (version 1.2.2, build 11).
SHA-256: `81169b383d954dc357597f8b8937a6b93b8dac050eb7818abfe393e63da99777`.
