import 'dart:async';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

/// Simulates the native Bluetooth boundary; runs the real Dart BLE stack.
/// RX fixtures are synthetic, not captures from the user's scooter.
final class FakeVicontPlatform extends FlutterBluePlusPlatform {
  final scans = StreamController<BmScanResponse>.broadcast();
  @override
  Stream<BmScanResponse> get onScanResponse => scans.stream;
  final connections = StreamController<BmConnectionStateResponse>.broadcast();
  final services = StreamController<BmDiscoverServicesResult>.broadcast();
  final received = StreamController<BmCharacteristicData>.broadcast();
  final written = StreamController<BmCharacteristicData>.broadcast();
  final descriptors = StreamController<BmDescriptorData>.broadcast();
  void Function(List<int>)? onWrite;
  final writes = <BmWriteCharacteristicRequest>[];
  String profile = 'fff0';
  bool supported = true;
  bool exposeService = true;
  bool failWrites = false;
  bool withoutResponseOnly = false;
  int connectCount = 0;
  int disconnectCount = 0;
  DeviceIdentifier remote = const DeviceIdentifier('QA-SCOOTER');
  Guid get service => Guid(profile);
  Guid get characteristic => Guid(profile == 'fff0' ? 'fff1' : 'fee2');
  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged =>
      connections.stream;
  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices => services.stream;
  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived => received.stream;
  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten => written.stream;
  @override
  Stream<BmDescriptorData> get onDescriptorWritten => descriptors.stream;
  @override
  Future<bool> startScan(BmScanSettings request) async {
    scans.add(BmScanResponse(advertisements: [
      BmScanAdvertisement(
          remoteId: remote,
          platformName: 'QA Werhy scooter',
          advName: 'QA Werhy scooter',
          connectable: true,
          txPowerLevel: null,
          appearance: null,
          manufacturerData: {},
          serviceData: {},
          serviceUuids: [service],
          rssi: -45)
    ], success: true, errorCode: 0, errorString: ''));
    return true;
  }

  @override
  Future<bool> isSupported(BmIsSupportedRequest request) async => supported;
  @override
  Future<BmBluetoothAdapterState> getAdapterState(
          BmBluetoothAdapterStateRequest request) async =>
      BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);
  void connection(bool connected) => connections.add(BmConnectionStateResponse(
      remoteId: remote,
      connectionState: connected
          ? BmConnectionStateEnum.connected
          : BmConnectionStateEnum.disconnected,
      disconnectReasonCode: null,
      disconnectReasonString: null));
  @override
  Future<bool> connect(BmConnectRequest request) async {
    remote = request.remoteId;
    connectCount++;
    connection(true);
    return true;
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) async {
    disconnectCount++;
    connection(false);
    return true;
  }

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) async {
    services.add(BmDiscoverServicesResult(
        remoteId: remote,
        success: true,
        errorCode: 0,
        errorString: '',
        services: exposeService
            ? [
                BmBluetoothService(
                    remoteId: remote,
                    serviceUuid: service,
                    primaryServiceUuid: null,
                    characteristics: [
                      BmBluetoothCharacteristic(
                          remoteId: remote,
                          serviceUuid: service,
                          characteristicUuid: characteristic,
                          primaryServiceUuid: null,
                          descriptors: [],
                          properties: BmCharacteristicProperties(
                              broadcast: false,
                              read: false,
                              write: !withoutResponseOnly,
                              writeWithoutResponse: withoutResponseOnly,
                              notify: true,
                              indicate: false,
                              authenticatedSignedWrites: false,
                              extendedProperties: false,
                              notifyEncryptionRequired: false,
                              indicateEncryptionRequired: false))
                    ])
              ]
            : []));
    return true;
  }

  @override
  Future<bool> setNotifyValue(BmSetNotifyValueRequest request) async {
    descriptors.add(BmDescriptorData(
        remoteId: remote,
        serviceUuid: service,
        characteristicUuid: characteristic,
        descriptorUuid: Guid('2902'),
        primaryServiceUuid: null,
        value: [1, 0],
        success: true,
        errorCode: 0,
        errorString: ''));
    return true;
  }

  BmCharacteristicData data(List<int> bytes, {bool success = true}) =>
      BmCharacteristicData(
          remoteId: remote,
          serviceUuid: service,
          characteristicUuid: characteristic,
          primaryServiceUuid: null,
          value: bytes,
          success: success,
          errorCode: success ? 0 : 1,
          errorString: success ? '' : 'Simulated write failure');
  @override
  Future<bool> writeCharacteristic(BmWriteCharacteristicRequest request) async {
    writes.add(request);
    onWrite?.call(request.value);
    written.add(data(request.value, success: !failWrites));
    return true;
  }

  void notify(List<int> bytes) => received.add(data(bytes));
  void telemetry(
      {int speedTenths = 0,
      bool locked = false,
      bool? brakeLocked,
      bool light = false,
      int gearMask = 7,
      int gear = 1,
      bool cruise = false,
      bool zeroStart = false}) {
    notify([
      90,
      16,
      12,
      16,
      104,
      0,
      12,
      speedTenths >> 8,
      speedTenths & 255,
      75,
      30,
      31,
      32,
      3,
      232
    ]);
    notify([
      90,
      17,
      10,
      gear | (light ? 8 : 0) | (cruise ? 64 : 0) | (zeroStart ? 32 : 0),
      1 | (locked ? 2 : 0),
      0,
      123,
      0,
      69,
      0,
      0,
      (brakeLocked ?? locked) ? 4 : 0,
      0
    ]);
    notify([90, 18, 9, 0, 0, 0, 0, 0, 0, 0, 0, gearMask]);
  }
}
