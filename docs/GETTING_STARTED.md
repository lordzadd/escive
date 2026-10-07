# Werhy / Vicont fork

This fork adds local Vicont Bluetooth controls to eScive.
Hardware compatibility is not yet verified.

## Ready for signing

The unsigned iPhone release is `build/ios/ipa/eScive-Werhy-unsigned.ipa`.
It needs signing with your Apple development account before installation.
The IPA contains the phone app. The legacy watch app is separate.
Hardware operation remains unverified.

## Phone build

The verified Flutter toolchain is Flutter 3.29.1 / Dart 3.7.0.

```sh
flutter pub get
cp .env.example .env
flutter test
flutter analyze
flutter build ios --release --no-codesign
```

Bluetooth controls do not require map or weather API keys.
Leave those values empty if you do not use those features.
The local checkout already contains an empty `.env` file.
Do not copy another person's provider credentials into this app.

Open `ios/Runner.xcworkspace` in Xcode.
Select your signing team and iPhone.
The full iPhone build requires the relevant iOS platform in Xcode Settings > Components.
The platform is now installed on this Mac.
See `VALIDATION.md` for the release build result.

## Documents

- `VICONT_PROTOCOL.md`: source evidence, implemented controls, and hardware checks.
- `APPLE_WATCH.md`: Series 2 sources, target setup, and installation limits.
- `VALIDATION.md`: test and build results.

The original eScive README remains below the fork note in the main README.
