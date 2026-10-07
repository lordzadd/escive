# APK lock trace — 2026-10-07

## Finding

The fork reversed the payload used by Vicont's main-screen LockCar toggle.
The extracted toggle sends command 0x33 with 02 when lockCarState is 0, and 01 when it is 1.
The previous fork sent 01 for a lock request and 02 for unlock.
The source difference is confirmed. Whether correcting it produces physical P remains a hardware check.

## Input and decompilation

Input: com.vicontout.benben.apk, SHA-256 recorded in VICONT_PROTOCOL.md.
The JavaScript bundle is an APK asset, not a separately guessed protocol specification.
JADX decompiled the DEX code into the local research directory `jadx-vicont`.
JADX reports 95 errors across the entire application.
The relevant Bluetooth write and hex-conversion methods contain complete decompiled bodies without error stubs.
This is not a claim that every APK class decompiled successfully.

The vendor code stays outside the Git repository.

## End-to-end source path

References use app-service.pretty.js in the local research directory.

| Step | Source evidence | Result |
| --- | --- | --- |
| Feature selection | Main home render, around 15765; btnHideArr; getFunctionList | LockCar visibility comes from the model feature list. The button does not substitute an accessory command. |
| Button handler | Around 15782 | Calls sendSwitch(51, bleDeviceInfo.lockCarState). |
| Preconditions | sendSwitch, 123964 onward | Requires Bluetooth when zcBle; refuses lock commands above 1 km/h. |
| Value selection | Around 124009 | For code 51: current state 1 maps to payload 1; other state maps to payload 2. |
| Parallel server call | postDeviceQuickInstructHandle, 123655 onward | Reports a quick instruction. The Bluetooth write is not gated on that asynchronous response. |
| Packet encoding | writeDisposeHandle, 124185 onward | Adds FA AF A5, received header, code, payload length, payload, and additive checksum. |
| Byte conversion | writeBleHandle, 124248; hexTobuffer, 157325 | Converts each hex pair to a byte; no lock-specific transformation. |
| Bluetooth write | Ble.writeBle, around 9405 | Delays 300 ms; passes the same buffer to uni.writeBLECharacteristicValue. iOS requests write, Android requests writeNoResponse. |
| Native dispatch | BluetoothFeature.java:162 | Forwards writeBLECharacteristicValue to BluetoothBaseAdapter. |
| Native adapter | BluetoothBaseAdapter.java:580 and 601 | Converts hex pairs, calls characteristic.setValue(bytes), then BluetoothGatt.writeCharacteristic. No lock-specific inversion or encryption. |
| Receive status | updateBleDeviceInfo, 33165–33179 | Electronic lock is byte 4 bit 1; binding is byte 4 bit 6; brake lock is byte 11 bit 2. |
| Model-specific follow-up | Around 33210 | Only versionType 1 synchronizes binding with 0x4C. A binding flag alone does not establish versionType. |

## Executed source, not inferred command names

The local harness `trace-lock.cjs` extracts the actual sendSwitch, writeDisposeHandle,
writeBleHandle, and Ble.writeBle functions from the supplied bundle.
It runs these functions with mocked platform calls and records the outgoing Bluetooth buffer.
The harness mocks scheduling, logging, storage, and server reporting; it does not contact a scooter or vendor service.
Native conversion and GATT dispatch were inspected separately, not executed on Android hardware.

Eight fixtures cover two states, two headers, and Android/iOS transport options.
The repository stores only the generated vectors in test/vicont_lock_main_screen_vectors.json.

| Current electronic-lock flag | Requested transition | 5A-header packet |
| --- | --- | --- |
| 0 | Lock | FA AF A5 5A 33 01 02 90 |
| 1 | Unlock | FA AF A5 5A 33 01 01 8F |

## Conflicting evidence that caused the earlier mistake

The separate instrument-panel screen has explicit buttons passing 1 and 2 to setLockHandle.
Inferring their meaning from icon names was insufficient.
That path differs from the main-screen toggle and does not override the executed toggle evidence.
The corrected fork now matches the main-screen toggle.
The user's exact Vicont screen and firmware behavior are not established by JavaScript execution alone.

The 0x3A handler controls a separate accessory brake action. The user's physical test rejected that experiment.
The 0x4C experiment assumed a model branch that has not been established. It is removed.

## Correction

Version 1.2.3 uses 0x33/02 to request lock and 0x33/01 to request unlock.
It does not send 0x3A or infer permission to send 0x4C from the binding flag.
It waits for fresh electronic-lock and brake-lock feedback, with timeout and disconnect handling.
Binding can remain on in either state and is displayed separately.
The UI is unchanged from the restored 1.1.2 layout.

The earlier command labels in the historical validation sections are superseded by this trace.
Physical P and immobilization remain manual acceptance criteria.
