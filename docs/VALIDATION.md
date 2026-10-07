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
