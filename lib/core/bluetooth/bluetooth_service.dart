import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart' as bc;
import 'package:permission_handler/permission_handler.dart';
import '../models/device_model.dart';

enum ActiveConnectionType { none, classicSpp, bleGatt }

class RealBluetoothService extends ChangeNotifier {
  static final RealBluetoothService _instance = RealBluetoothService._internal();
  factory RealBluetoothService() => _instance;

  RealBluetoothService._internal() {
    _initBluetoothListeners();
  }

  // Dual-mode Bluetooth engines
  final BluetoothClassic _classic = BluetoothClassic();

  // --- Real Bluetooth State ---
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  bool isScanning = false;
  String? lastError;
  bool isPermissionGranted = false;
  bool isLocationEnabled = true;

  ActiveConnectionType activeType = ActiveConnectionType.none;
  String? connectedMac;
  String? connectedName;

  // Real world discovered & bonded devices
  List<RoboticDevice> realNearbyDevices = [];
  List<RoboticDevice> realBondedDevices = [];
  final Map<String, BluetoothDevice> _bleDeviceMap = {};
  final Set<String> _knownBleMacs = {};

  BluetoothDevice? connectedBleDevice;
  BluetoothCharacteristic? _bleTxChar;
  BluetoothCharacteristic? _bleRxChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<bc.Device>? _classicDiscoverySub;
  StreamSubscription<int>? _classicStatusSub;
  StreamSubscription<Uint8List>? _classicDataSub;
  StreamSubscription<BluetoothConnectionState>? _bleConnSub;
  StreamSubscription<List<int>>? _bleDataSub;

  Function(String data)? onDataReceived;

  void _initBluetoothListeners() {
    try {
      _adapterSub = FlutterBluePlus.adapterState.listen((state) {
        adapterState = state;
        notifyListeners();
      });

      _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
        isScanning = scanning;
        notifyListeners();
      });

      // Bluetooth Classic status listener: 0 = disconnected, 1 = connecting, 2 = connected
      _classicStatusSub = _classic.onDeviceStatusChanged().listen((status) {
        debugPrint("[Classic Service] onDeviceStatusChanged: status=$status (0=disc, 1=conn-ing, 2=conn-ed)");
        if (status == bc.Device.connected) {
          // Status 2: Hardware RFCOMM socket established
          if (activeType != ActiveConnectionType.classicSpp) {
            activeType = ActiveConnectionType.classicSpp;
            notifyListeners();
          }
        } else if (status == bc.Device.disconnected) {
          // Status 0: Remote device disconnected or link dropped
          if (activeType == ActiveConnectionType.classicSpp) {
            activeType = ActiveConnectionType.none;
            connectedMac = null;
            connectedName = null;
            lastError = "Bluetooth Classic connection disconnected.";
            notifyListeners();
          }
        }
      });

      _classicDataSub = _classic.onDeviceDataReceived().listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        onDataReceived?.call(text);
      });

      checkLocationService();
    } catch (e) {
      debugPrint("[BLE Service] Init error: $e");
    }
  }

  Future<bool> checkLocationService() async {
    if (Platform.isAndroid) {
      try {
        isLocationEnabled = await Permission.location.serviceStatus.isEnabled;
        notifyListeners();
        return isLocationEnabled;
      } catch (_) {}
    }
    return true;
  }

  // --- 1. Request Real Android Permissions ---
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        try {
          await _classic.initPermissions();
        } catch (_) {}

        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        await checkLocationService();

        final scanGranted = statuses[Permission.bluetoothScan]?.isGranted == true ||
            statuses[Permission.bluetoothScan]?.isLimited == true ||
            statuses[Permission.location]?.isGranted == true;

        final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted == true ||
            statuses[Permission.bluetoothConnect]?.isLimited == true ||
            statuses[Permission.location]?.isGranted == true;

        isPermissionGranted = scanGranted && connectGranted;
        notifyListeners();
        return isPermissionGranted;
      }
      isPermissionGranted = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[BLE Service] Permission request error: $e");
      return false;
    }
  }

  // --- 2. Check & Turn On Bluetooth ---
  Future<bool> ensureBluetoothOn() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        lastError = "Bluetooth hardware not supported on this device.";
        notifyListeners();
        return false;
      }

      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (e) {
            debugPrint("[BLE Service] Prompt turn on error: $e");
          }
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint("[BLE Service] turnOn error: $e");
      lastError = "Could not activate Bluetooth: $e";
      notifyListeners();
      return false;
    }
  }

  // --- 3. Get Real Paired / Bonded Devices (Both Classic & BLE) ---
  Future<List<RoboticDevice>> getBondedDevices() async {
    final Map<String, RoboticDevice> uniqueBonded = {};

    // A. Query Bluetooth Classic paired devices (HC-05, HC-06, etc.)
    try {
      final classicList = await _classic.getPairedDevices();
      for (var dev in classicList) {
        final mac = dev.address.trim();
        if (mac.isEmpty) continue;
        final macUpper = mac.toUpperCase();
        String name = dev.name?.trim() ?? "";
        if (name.isEmpty) {
          final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
          name = "Paired Device ($shortMac)";
        }

        uniqueBonded[macUpper] = RoboticDevice(
          id: "bonded-$mac",
          name: name,
          macAddress: mac,
          ipAddress: "",
          protocol: "Bluetooth (Classic)",
          rssi: -50,
          isConnected: (activeType == ActiveConnectionType.classicSpp && connectedMac?.toUpperCase() == macUpper),
          deviceType: _guessDeviceType(name),
        );
      }
    } catch (e) {
      debugPrint("[Classic Service] getPairedDevices error: $e");
    }

    // B. Query BLE bonded & system devices
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (isSupported) {
        final bonded = await FlutterBluePlus.bondedDevices;
        List<BluetoothDevice> sysConnected = [];
        try {
          sysConnected = await FlutterBluePlus.systemDevices([]);
        } catch (_) {}

        for (var dev in [...bonded, ...sysConnected]) {
          final mac = dev.remoteId.str.trim();
          if (mac.isEmpty) continue;
          final macUpper = mac.toUpperCase();
          String name = dev.platformName.trim();
          if (name.isEmpty) name = dev.advName.trim();
          if (name.isEmpty && uniqueBonded.containsKey(macUpper)) {
            name = uniqueBonded[macUpper]!.name;
          }
          final upperName = name.toUpperCase();
          if (uniqueBonded.containsKey(macUpper) ||
              upperName.contains("HC-05") ||
              upperName.contains("HC05") ||
              upperName.contains("HC-06") ||
              upperName.contains("HC06") ||
              upperName.contains("BT05") ||
              upperName.contains("CLASSIC")) {
            // HC-05 / HC-06 is Bluetooth Classic SPP, not BLE GATT. Keep Classic registration!
            continue;
          }

          _bleDeviceMap[mac] = dev;
          _bleDeviceMap[macUpper] = dev;
          _bleDeviceMap[mac.toLowerCase()] = dev;
          _knownBleMacs.add(macUpper);

          if (name.isEmpty) {
            final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
            name = "Paired Device ($shortMac)";
          }

          final bool isDevConnected = dev.isConnected ||
              (activeType == ActiveConnectionType.bleGatt && connectedMac?.toUpperCase() == macUpper);

          uniqueBonded[macUpper] = RoboticDevice(
            id: uniqueBonded[macUpper]?.id ?? "bonded-$mac",
            name: name,
            macAddress: mac,
            ipAddress: "",
            protocol: "BLE UART",
            rssi: -55,
            isConnected: isDevConnected,
            deviceType: _guessDeviceType(name),
          );
        }
      }
    } catch (e) {
      debugPrint("[BLE Service] getBondedDevices error: $e");
    }

    realBondedDevices = uniqueBonded.values.toList();
    notifyListeners();
    return realBondedDevices;
  }

  // --- 4. Start Real Nearby Bluetooth Scan (Dual: Classic + BLE) ---
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    lastError = null;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      lastError = "Bluetooth permission was not granted. Please allow nearby device permissions in settings.";
      notifyListeners();
      return;
    }

    final isBtOn = await ensureBluetoothOn();
    if (!isBtOn) {
      lastError = "Please turn on Bluetooth to scan for real devices.";
      notifyListeners();
      return;
    }

    await getBondedDevices();

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      try {
        await _classic.stopScan();
      } catch (_) {}

      realNearbyDevices.clear();
      isScanning = true;
      notifyListeners();

      final Map<String, RoboticDevice> unique = {};

      void updateList() {
        realNearbyDevices = unique.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        notifyListeners();
      }

      // Stream A: BLE Scan
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (var res in results) {
          final dev = res.device;
          final mac = dev.remoteId.str;
          final macUpper = mac.toUpperCase();
          _bleDeviceMap[mac] = dev;
          _bleDeviceMap[macUpper] = dev;
          _bleDeviceMap[mac.toLowerCase()] = dev;
          _knownBleMacs.add(macUpper);

          String name = dev.platformName.trim();
          if (name.isEmpty) name = res.advertisementData.advName.trim();
          if (name.isEmpty) {
            final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
            name = "BLE Device ($shortMac)";
          }

          unique[mac] = RoboticDevice(
            id: "real-$mac",
            name: name,
            macAddress: mac,
            ipAddress: "",
            protocol: "BLE 5.2",
            rssi: res.rssi,
            isConnected: dev.isConnected,
            deviceType: _guessDeviceType(name),
          );
        }
        updateList();
      });

      // Stream B: Classic Discovery
      _classicDiscoverySub?.cancel();
      _classicDiscoverySub = _classic.onDeviceDiscovered().listen((dev) {
        final mac = dev.address.trim();
        if (mac.isEmpty) return;

        String name = dev.name?.trim() ?? "";
        if (name.isEmpty) {
          final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
          name = "Classic BT ($shortMac)";
        }

        if (!unique.containsKey(mac)) {
          unique[mac] = RoboticDevice(
            id: "real-$mac",
            name: name,
            macAddress: mac,
            ipAddress: "",
            protocol: "Bluetooth (Classic)",
            rssi: -55,
            isConnected: (activeType == ActiveConnectionType.classicSpp && connectedMac == mac),
            deviceType: _guessDeviceType(name),
          );
          updateList();
        }
      });

      // Launch both scans
      await Future.wait([
        FlutterBluePlus.startScan(timeout: timeout).catchError((e) {
          debugPrint("[BLE] Scan error: $e");
        }),
        _classic.startScan().catchError((e) {
          debugPrint("[Classic] Scan error: $e");
          return false;
        }),
      ]);

      // Timer to stop classic after timeout
      Future.delayed(timeout, () {
        stopScan();
      });
    } catch (e) {
      debugPrint("[BLE Service] startScan error: $e");
      lastError = "Scan failed: $e";
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await _classic.stopScan();
    } catch (_) {}
    isScanning = false;
    notifyListeners();
  }

  // Helper to determine if a device requires Bluetooth Classic Serial Port Profile (SPP)
  bool isClassicSppDevice(RoboticDevice device) {
    final name = device.name.toUpperCase();
    if (name.contains("HC-05") ||
        name.contains("HC05") ||
        name.contains("HC-06") ||
        name.contains("HC06") ||
        name.contains("HC-") ||
        name.contains("SPP") ||
        name.contains("ARDUINO") ||
        name.contains("CLASSIC") ||
        name.contains("BT05")) {
      return true;
    }
    final protocol = device.protocol.toUpperCase();
    if (protocol.contains("CLASSIC") || protocol.contains("SPP")) {
      return true;
    }
    final macUpper = device.macAddress.toUpperCase();
    if (_knownBleMacs.contains(macUpper) ||
        _bleDeviceMap.containsKey(macUpper) ||
        _bleDeviceMap.containsKey(device.macAddress.toLowerCase())) {
      return false;
    }
    if (protocol.contains("BLE")) {
      return false;
    }
    if (device.id.startsWith("bonded-") && !protocol.contains("BLE")) {
      return true;
    }
    return false;
  }

  // Setup BLE UART characteristics (FFE1, Nordic UART, or generic writable/notify characteristics)
  Future<bool> _setupBleUart(BluetoothDevice bleDevice) async {
    try {
      _bleTxChar = null;
      _bleRxChar = null;
      final services = await bleDevice.discoverServices();
      for (var s in services) {
        debugPrint("[BLE GATT] Service: ${s.uuid}");
        for (var c in s.characteristics) {
          debugPrint("[BLE GATT] Char: ${c.uuid}, write=${c.properties.write}, writeNoResp=${c.properties.writeWithoutResponse}, notify=${c.properties.notify}");
          final uuidStr = c.uuid.str.toLowerCase();
          if (uuidStr.contains("ffe1") ||
              uuidStr.contains("6e400002") ||
              uuidStr.contains("6e400003") ||
              c.properties.write ||
              c.properties.writeWithoutResponse) {
            _bleTxChar ??= c;
          }
          if (c.properties.notify || c.properties.indicate) {
            _bleRxChar ??= c;
            try {
              await c.setNotifyValue(true);
              _bleDataSub?.cancel();
              _bleDataSub = c.onValueReceived.listen((data) {
                final text = utf8.decode(data, allowMalformed: true);
                onDataReceived?.call(text);
              });
            } catch (e) {
              debugPrint("[BLE GATT] Error setting notify: $e");
            }
          }
        }
      }
      return _bleTxChar != null;
    } catch (e) {
      debugPrint("[BLE GATT] Service discovery error: $e");
      return false;
    }
  }

  // --- 5. Connect to Real Hardware Device (Classic SPP or BLE GATT) ---
  Future<bool> connect(RoboticDevice device) async {
    final mac = device.macAddress.trim();
    if (mac.isEmpty) return false;
    final macUpper = mac.toUpperCase();
    lastError = null;

    // Disconnect any existing link first
    await disconnect();

    // Cancel active scans so the Bluetooth radio is completely free for handshake
    await stopScan();

    // Ensure real Bluetooth permissions are verified before connecting
    await requestPermissions();
    try {
      await _classic.initPermissions();
    } catch (_) {}

    const String sppUuid = "00001101-0000-1000-8000-00805f9b34fb";

    final bool forceClassic = isClassicSppDevice(device);

    bool isBle = false;
    if (!forceClassic) {
      isBle = _knownBleMacs.contains(macUpper) ||
          _bleDeviceMap.containsKey(macUpper) ||
          _bleDeviceMap.containsKey(mac.toLowerCase()) ||
          device.protocol.toUpperCase().contains("BLE");

      if (!isBle) {
        try {
          final sys = await FlutterBluePlus.systemDevices([]);
          for (var s in sys) {
            if (s.remoteId.str.toUpperCase() == macUpper) {
              isBle = true;
              _knownBleMacs.add(macUpper);
              _bleDeviceMap[mac] = s;
              _bleDeviceMap[macUpper] = s;
              break;
            }
          }
        } catch (_) {}
      }
    }

    final bool isClassic = forceClassic || !isBle;

    // 1. Try Classic SPP (HC-05, HC-06, Arduino, etc.)
    if (isClassic) {
      debugPrint("[Classic SPP] Initiating RFCOMM connection to $mac with UUID $sppUuid...");
      try {
        final success = await _classic.connect(mac, sppUuid).timeout(
          const Duration(seconds: 8),
          onTimeout: () => false,
        );
        if (success) {
          activeType = ActiveConnectionType.classicSpp;
          connectedMac = mac;
          connectedName = device.name;
          lastError = null;
          notifyListeners();
          debugPrint("[Classic SPP] Connection successfully established to $mac");
          return true;
        } else {
          lastError = "Could not establish connection to ${device.name}. Ensure device is powered on and paired in phone Settings.";
        }
      } catch (e) {
        debugPrint("[Classic SPP] RFCOMM connect error: $e");
        lastError = "Bluetooth connection error: $e";
      }
      if (forceClassic) {
        notifyListeners();
        return false;
      }
      debugPrint("[Classic SPP] RFCOMM failed or device is BLE. Falling back to BLE GATT for $mac...");
    }

    // 2. BLE GATT connection branch (Supports BLE UART modules like AT-09, CC2541, JDY-30, HC-05 BLE)
    final bleDevice = _bleDeviceMap[mac] ??
        _bleDeviceMap[macUpper] ??
        _bleDeviceMap[mac.toLowerCase()] ??
        BluetoothDevice.fromId(mac);

    try {
      debugPrint("[BLE Service] Attempting BLE GATT connect to $mac (alreadyConnected=\${bleDevice.isConnected})...");
      if (!bleDevice.isConnected) {
        try {
          await bleDevice.connect(
            timeout: const Duration(seconds: 6),
            license: License.nonprofit,
            autoConnect: false,
          );
        } catch (e) {
          debugPrint("[BLE Service] bleDevice.connect note: $e");
          final errStr = e.toString().toLowerCase();
          if (!errStr.contains("already") && !bleDevice.isConnected) {
            await Future.delayed(const Duration(milliseconds: 250));
            if (!bleDevice.isConnected) {
              rethrow;
            }
          }
        }
      }

      _bleConnSub?.cancel();
      _bleConnSub = bleDevice.connectionState.listen((state) {
        debugPrint("[BLE Service] Connection state changed: $state");
        if (state == BluetoothConnectionState.disconnected && activeType == ActiveConnectionType.bleGatt) {
          activeType = ActiveConnectionType.none;
          connectedMac = null;
          connectedName = null;
          _bleTxChar = null;
          _bleRxChar = null;
          lastError = "BLE device disconnected.";
          notifyListeners();
        }
      });

      // Discover UART characteristics (FFE1, Nordic UART, etc.)
      final uartFound = await _setupBleUart(bleDevice);
      if (!uartFound) {
        throw Exception("Could not discover writable UART characteristic (FFE1) on \${device.name}");
      }

      connectedBleDevice = bleDevice;
      activeType = ActiveConnectionType.bleGatt;
      connectedMac = mac;
      connectedName = device.name;
      _knownBleMacs.add(macUpper);
      _bleDeviceMap[macUpper] = bleDevice;
      _bleDeviceMap[mac] = bleDevice;
      lastError = null;
      notifyListeners();
      debugPrint("[BLE Service] Connected to $mac via BLE GATT with TX char: \${_bleTxChar?.uuid}");
      return true;
    } catch (e) {
      debugPrint("[BLE Service] BLE GATT connection error: $e");
      try {
        await bleDevice.disconnect();
      } catch (_) {}
      activeType = ActiveConnectionType.none;
      connectedMac = null;
      connectedName = null;
      lastError = "Could not connect to \${device.name} ($mac): $e";
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendData(String message) async {
    try {
      debugPrint("[Bluetooth Service] TX: ${message.trim()} (mode: $activeType, mac: $connectedMac)");
      if (activeType == ActiveConnectionType.classicSpp) {
        final ok = await _classic.write(message);
        debugPrint("[Classic Service] write result: $ok");
        if (!ok) {
          debugPrint("[Classic Service] WARNING: _classic.write returned false. Link may be lost.");
          lastError = "Write failed: Device rejected transmission.";
          notifyListeners();
          return false;
        }
        return true;
      } else if (activeType == ActiveConnectionType.bleGatt && connectedBleDevice != null) {
        if (_bleTxChar != null) {
          final bytes = utf8.encode(message);
          if (_bleTxChar!.properties.writeWithoutResponse) {
            await _bleTxChar!.write(bytes, withoutResponse: true);
          } else {
            await _bleTxChar!.write(bytes);
          }
          debugPrint("[BLE Service] GATT TX successful: ${message.trim()}");
          return true;
        } else {
          debugPrint("[BLE Service] WARNING: No writable BLE characteristic configured.");
          lastError = "No writable characteristic found on BLE device.";
          return false;
        }
      } else {
        debugPrint("[Bluetooth Service] TX dropped: no active connection (activeType=$activeType)");
        lastError = "Cannot send data: not connected to any Bluetooth device.";
        return false;
      }
    } catch (e) {
      debugPrint("[Bluetooth Service] sendData exception: $e");
      lastError = "Write error: $e";
      if (activeType == ActiveConnectionType.classicSpp) {
        activeType = ActiveConnectionType.none;
        connectedMac = null;
        connectedName = null;
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      if (activeType == ActiveConnectionType.classicSpp) {
        await _classic.disconnect();
      }
      if (connectedBleDevice != null) {
        await _bleConnSub?.cancel();
        _bleConnSub = null;
        await _bleDataSub?.cancel();
        _bleDataSub = null;
        _bleTxChar = null;
        _bleRxChar = null;
        await connectedBleDevice!.disconnect();
        connectedBleDevice = null;
      }
      activeType = ActiveConnectionType.none;
      connectedMac = null;
      connectedName = null;
      notifyListeners();
    } catch (e) {
      debugPrint("[BLE Service] Disconnect error: $e");
    }
  }

  static String _guessDeviceType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('car') || lower.contains('rover') || lower.contains('mecanum') || lower.contains('bot')) {
      return "Rover";
    } else if (lower.contains('arm') || lower.contains('servo')) {
      return "Arm";
    } else if (lower.contains('cam') || lower.contains('camera')) {
      return "Cam";
    } else if (lower.contains('lamp') || lower.contains('led') || lower.contains('rgb') || lower.contains('relay')) {
      return "Relay";
    } else if (lower.contains('headphone') || lower.contains('audio') || lower.contains('buds') || lower.contains('speaker')) {
      return "Audio";
    }
    return "Node";
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _adapterSub?.cancel();
    _classicDiscoverySub?.cancel();
    _classicStatusSub?.cancel();
    _classicDataSub?.cancel();
    super.dispose();
  }
}
