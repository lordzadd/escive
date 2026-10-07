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
