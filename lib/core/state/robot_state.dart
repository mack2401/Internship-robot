import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../database/device_database.dart';
import '../bluetooth/bluetooth_service.dart';
import '../wifi/wifi_service.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class RobotState extends ChangeNotifier {
  static final RobotState _instance = RobotState._internal();
  factory RobotState() => _instance;

  final DeviceProfileDatabase database = DeviceProfileDatabase();
  final RealBluetoothService bleService = RealBluetoothService();
  final RealWifiService wifiService = RealWifiService();

  RobotState._internal() {
    _initTerminalLogs();
    _startSimulatedTelemetry();
    _loadPairedProfiles();
    _initBleListener();
    _initWifiListener();
    _refreshNearbyForProtocol(activeProtocol);
  }

  void _initWifiListener() {
    wifiService.addListener(_onWifiChanged);
    wifiService.onDataReceived = (data) {
      addTerminalLog(data.trim(), LogType.rx);
    };
  }

  void _onWifiChanged() {
    if (wifiService.isConnected) {
      if (connectionStatus != ConnectionStatus.connected) {
        connectionStatus = ConnectionStatus.connected;
        final modeLabel = wifiService.currentMode == WifiMode.softAp ? "Wi-Fi (SoftAP)" : "Wi-Fi (LAN)";
        currentDevice = currentDevice.copyWith(
          name: wifiService.currentDeviceName ?? currentDevice.name,
          ipAddress: wifiService.currentHost,
          protocol: modeLabel,
          isConnected: true,
          pingMs: wifiService.pingMs,
        );
        addTerminalLog("[SYS] Connected to ${currentDevice.name} (http://${wifiService.currentHost}:${wifiService.currentPort}) via $modeLabel", LogType.system);
      } else {
        if (wifiService.pingMs > 0) {
          linkLatency = wifiService.pingMs;
        }
        if (wifiService.telemetryData.isNotEmpty) {
          if (wifiService.telemetryData.containsKey("battery")) {
            final val = wifiService.telemetryData["battery"];
            if (val is num) batteryVoltage = val.toDouble();
          }
          if (wifiService.telemetryData.containsKey("distance")) {
            final val = wifiService.telemetryData["distance"];
            if (val is num) proximityDistance = val.toDouble();
          }
          if (wifiService.telemetryData.containsKey("temp")) {
            final val = wifiService.telemetryData["temp"];
            if (val is num) coreTemperature = val.toDouble();
          }
        }
      }
    } else {
      if (connectionStatus == ConnectionStatus.connected && (activeProtocol.contains("Wi-Fi") || activeProtocol.contains("WiFi"))) {
        connectionStatus = ConnectionStatus.disconnected;
        currentDevice = currentDevice.copyWith(isConnected: false);
        final err = wifiService.lastError ?? "Wi-Fi connection disconnected.";
        addTerminalLog("[SYS] $err", LogType.error);
      }
    }

    if (activeProtocol.contains("Wi-Fi") || activeProtocol.contains("WiFi")) {
      isScanning = wifiService.isScanningSubnet;
      if (wifiService.discoveredLanDevices.isNotEmpty) {
        final lanDevices = wifiService.discoveredLanDevices.map((d) => RoboticDevice(
          id: "wifi-${d.ip.replaceAll('.', '-')}",
          name: d.name,
          macAddress: "IP: ${d.ip}:${d.port}",
          ipAddress: d.ip,
          protocol: "Wi-Fi (LAN)",
          rssi: -45,
          pingMs: d.pingMs,
          deviceType: "Rover",
        )).toList();

        nearbyDiscoveredDevices = [
          const RoboticDevice(
            id: "esp-softap-default",
            name: "ESP32 Hotspot (SoftAP)",
            macAddress: "Gateway: 192.168.4.1",
            ipAddress: "192.168.4.1",
            protocol: "Wi-Fi (SoftAP)",
            rssi: -35,
            deviceType: "Rover",
          ),
          ...lanDevices,
        ];
      }
    }
    notifyListeners();
  }

  /// Unified transport dispatcher: Routes commands to Wi-Fi or Bluetooth automatically
  void sendPayload(String data) {
    final bool isBtActive = bleService.activeType != ActiveConnectionType.none;
    final bool isBtProtocol = activeProtocol.contains("Bluetooth") ||
        activeProtocol.contains("BLE") ||
        activeProtocol.contains("Classic") ||
        currentDevice.protocol.contains("Bluetooth") ||
        currentDevice.protocol.contains("Classic");

    if (isBtActive || isBtProtocol) {
      if (!isBtActive) {
        addTerminalLog("[BT OFFLINE] Command dropped: Not connected to Bluetooth device ($data)", LogType.error);
        bleService.lastError = "Not connected to Bluetooth device.";
        return;
      }
      bleService.sendData(data);
      addTerminalLog("[TX BT] ${data.trim()}", LogType.tx);
    } else {
      wifiService.sendCommand(data);
      addTerminalLog("[TX Wi-Fi] ${data.trim()}", LogType.tx);
    }
  }

  void _initBleListener() {
    bleService.addListener(_onBleChanged);
    bleService.onDataReceived = (data) {
      addTerminalLog(data.trim(), LogType.rx);
    };
    // Asynchronously load real phone bonded devices on launch
    bleService.getBondedDevices();
  }

  void _onBleChanged() {
    isScanning = bleService.isScanning;
    if (bleService.activeType != ActiveConnectionType.none) {
      if (connectionStatus != ConnectionStatus.connected) {
        connectionStatus = ConnectionStatus.connected;
        currentDevice = currentDevice.copyWith(
          name: bleService.connectedName ?? currentDevice.name,
          macAddress: bleService.connectedMac ?? currentDevice.macAddress,
          isConnected: true,
        );
        addTerminalLog("[SYS] Connected to ${currentDevice.name} (${currentDevice.macAddress}) via ${bleService.activeType == ActiveConnectionType.classicSpp ? 'Classic SPP' : 'BLE'}", LogType.system);
      }
    } else {
      // Bluetooth hardware is disconnected
      if (connectionStatus == ConnectionStatus.connected) {
        connectionStatus = ConnectionStatus.disconnected;
        currentDevice = currentDevice.copyWith(isConnected: false);
        final err = bleService.lastError ?? "Bluetooth connection disconnected.";
        addTerminalLog("[SYS] $err", LogType.error);
      }
    }
    if (activeProtocol.contains("Bluetooth") || activeProtocol.contains("BLE")) {
      nearbyDiscoveredDevices = List.from(bleService.realNearbyDevices);
    }
    notifyListeners();
  }

  // --- DEVICE CONNECTION & RADIO STATE ---
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  bool get isConnected => connectionStatus == ConnectionStatus.connected;
  String activeProtocol = "Bluetooth / BLE";
  bool isRadioEnabled = true;
  bool isScanning = false;

  RoboticDevice currentDevice = const RoboticDevice(
    id: "ibt-classic-01",
    name: "iBots Mecanum 4WD (Classic)",
    macAddress: "00:1A:7D:DA:71:13",
    ipAddress: "192.168.4.10",
    protocol: "Bluetooth (Classic)",
    rssi: -48,
    isConnected: false,
    batteryVoltage: 8.4,
    pingMs: 12,
    deviceType: "Rover",
  );

  RoboticDevice? targetDevice;

  List<DeviceProfile> pairedProfiles = [];
  List<RoboticDevice> nearbyDiscoveredDevices = [];

  List<RoboticDevice> get discoveredDevices => nearbyDiscoveredDevices;

  Future<void> _loadPairedProfiles() async {
    pairedProfiles = await database.getAllProfiles();
    notifyListeners();
  }

  void setProtocol(String protocol) {
    activeProtocol = protocol;
    _refreshNearbyForProtocol(protocol);
    // If not connected, also update current target profile
    final matchingPaired = pairedProfiles.where((p) {
      if (protocol.contains("Classic")) return p.protocol.contains("Classic");
      if (protocol.contains("BLE")) return p.protocol.contains("BLE");
      return p.protocol.contains("Wi-Fi") || p.protocol.contains("WiFi");
    }).toList();

    if (matchingPaired.isNotEmpty && !currentDevice.isConnected) {
      targetDevice = matchingPaired.first.toRoboticDevice();
    }
    notifyListeners();
  }

  void _refreshNearbyForProtocol(String protocol) {
    if (protocol.contains("Classic")) {
      nearbyDiscoveredDevices = [
        const RoboticDevice(
          id: "bt-hc05-01",
          name: "iBots HC-05 SPP Bridge",
          macAddress: "00:14:03:05:58:20",
          ipAddress: "192.168.4.15",
          protocol: "Bluetooth (Classic)",
          rssi: -42,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "bt-mecanum-02",
          name: "iBots Mecanum 4WD",
          macAddress: "00:1A:7D:DA:71:13",
          ipAddress: "192.168.4.10",
          protocol: "Bluetooth (Classic)",
          rssi: -48,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "bt-nano-03",
          name: "Arduino Nano Bluetooth",
          macAddress: "98:D3:31:FC:2B:7A",
          ipAddress: "192.168.4.18",
          protocol: "Bluetooth (Classic)",
          rssi: -68,
          deviceType: "Rover",
        ),
      ];
    } else if (protocol.contains("BLE")) {
      nearbyDiscoveredDevices = [
        const RoboticDevice(
          id: "ibt-4899",
          name: "iBots Rover ESP32-WROOM",
          macAddress: "24:6F:28:B2:1A:40",
          ipAddress: "192.168.4.1",
          protocol: "BLE 5.2",
          rssi: -54,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "ibt-arm-06",
          name: "iBots 6-DOF Robotic Arm",
          macAddress: "A4:CF:12:D5:78:10",
          ipAddress: "192.168.4.3",
          protocol: "BLE 5.2",
          rssi: -71,
          deviceType: "Arm",
        ),
        const RoboticDevice(
          id: "esp-relay-08",
          name: "ESP32-S3 SmartRelay Node",
          macAddress: "7C:DF:A1:40:9B:12",
          ipAddress: "192.168.4.8",
          protocol: "BLE 5.2",
          rssi: -59,
          deviceType: "Relay",
        ),
      ];
    } else {
      // Wi-Fi (SoftAP / LAN)
      nearbyDiscoveredDevices = [
        const RoboticDevice(
          id: "esp-softap-default",
          name: "ESP32 Hotspot (SoftAP)",
          macAddress: "Gateway: 192.168.4.1",
          ipAddress: "192.168.4.1",
          protocol: "Wi-Fi (SoftAP)",
          rssi: -35,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "esp-lan-default",
          name: "ESP32 Local Network (Router)",
          macAddress: "Host: esp32.local",
          ipAddress: "esp32.local",
          protocol: "Wi-Fi (LAN)",
          rssi: -50,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "ibt-cam-02",
          name: "iBots ESP32-CAM Streamer",
          macAddress: "IP: 192.168.4.1:81",
          ipAddress: "192.168.4.1",
          protocol: "Wi-Fi (SoftAP)",
          rssi: -52,
          deviceType: "Cam",
        ),
      ];
    }
  }

  void selectTargetDevice(RoboticDevice device) {
    targetDevice = device;
    currentDevice = device.copyWith(isConnected: false);
    activeProtocol = device.protocol;
    // Save to SQLite/Drift database profiles
    database.saveProfile(DeviceProfile.fromRoboticDevice(device));
    _loadPairedProfiles();
    addTerminalLog("[SYS] Selected target node: ${device.name} (${device.macAddress})", LogType.system);
    notifyListeners();
  }

  void toggleRadio(bool enabled) {
    isRadioEnabled = enabled;
    if (!enabled && currentDevice.isConnected) {
      disconnectDevice();
    }
    notifyListeners();
  }

  Future<void> startScanning() async {
    isScanning = true;
    notifyListeners();

    if (activeProtocol.contains("Bluetooth") || activeProtocol.contains("BLE") || activeProtocol.contains("Classic")) {
      addTerminalLog("[BLE] Requesting hardware permissions and scanning RF spectrum...", LogType.system);
      await bleService.startScan();
      isScanning = bleService.isScanning;
      if (bleService.realNearbyDevices.isNotEmpty) {
        nearbyDiscoveredDevices = List.from(bleService.realNearbyDevices);
      }
      notifyListeners();
    } else {
      // Real Wi-Fi scan: Scan real over-the-air Wi-Fi access points visible to the phone
      addTerminalLog("[Wi-Fi] Scanning for real visible Wi-Fi networks & ESP devices...", LogType.system);
      await wifiService.scanRealWifiNetworks();
      isScanning = wifiService.isScanningNetworks;

      final List<RoboticDevice> list = [];
      for (var n in wifiService.availableNetworks) {
        list.add(RoboticDevice(
          id: "wifi-${n.ssid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}",
          name: n.ssid,
          macAddress: n.bssid.isNotEmpty ? n.bssid : (n.isEspDevice ? "192.168.4.1" : "Wi-Fi AP"),
          ipAddress: n.isEspDevice ? "192.168.4.1" : "",
          protocol: n.isEspDevice ? "Wi-Fi (SoftAP)" : "Wi-Fi (LAN)",
          rssi: n.level,
          deviceType: n.isEspDevice ? "Rover" : "Gateway",
          isConnected: n.isConnected,
        ));
      }
      if (list.isNotEmpty) {
        nearbyDiscoveredDevices = list;
        addTerminalLog("[Wi-Fi] Found ${list.length} visible Wi-Fi network(s) in range.", LogType.system);
      }
      notifyListeners();
    }
  }

  Future<void> connectToTargetDevice() async {
    final dev = targetDevice ?? currentDevice;
    connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    addTerminalLog("[${dev.protocol}] Handshake initiated with ${dev.name} (${dev.macAddress})...", LogType.bluetooth);

    const fakeMockMacs = {
      "00:1A:7D:DA:71:13",
      "00:14:03:05:58:20",
      "98:D3:31:FC:2B:7A",
      "24:6F:28:B2:1A:40",
      "A4:CF:12:D5:78:10",
      "7C:DF:A1:40:9B:12",
    };

    final bool isFakeMock = fakeMockMacs.contains(dev.macAddress.toUpperCase()) &&
        (dev.id == "bt-hc05-01" ||
            dev.id == "bt-mecanum-02" ||
            dev.id == "bt-nano-03" ||
            dev.id == "ibt-classic-01" ||
            dev.id == "ibt-4899");

    final bool isRealHardware = !isFakeMock &&
        (dev.id.startsWith("real-") ||
            dev.id.startsWith("bonded-") ||
            RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$').hasMatch(dev.macAddress));

    final bool isWifiProto = dev.protocol.contains("Wi-Fi") || dev.protocol.contains("WiFi");

    bool success = false;
    if (isWifiProto) {
      final isSoftAp = dev.ipAddress == "192.168.4.1" || dev.protocol.contains("SoftAP") || dev.protocol.contains("Hotspot") || dev.protocol.contains("AP");
      addTerminalLog("[Wi-Fi] Connecting to ${dev.name} (http://${dev.ipAddress}) [${isSoftAp ? 'Hotspot Mode' : 'Local Router Mode'}]...", LogType.system);
      success = await wifiService.connect(
        host: dev.ipAddress.isNotEmpty ? dev.ipAddress : "192.168.4.1",
        mode: isSoftAp ? WifiMode.softAp : WifiMode.localNetwork,
        name: dev.name,
      );
    } else if (isRealHardware) {
      addTerminalLog("[SYS] Connecting to real hardware ${dev.macAddress}...", LogType.system);
      success = await bleService.connect(dev);
    } else {
      // Mock demo device tapped: Do NOT claim connection!
      await Future.delayed(const Duration(milliseconds: 600));
      addTerminalLog("[DEMO] '${dev.name}' is a sample demo profile. Pair your physical HC-05 in phone Bluetooth Settings and select it from 'Paired & Saved Devices'.", LogType.error);
      success = false;
    }

    if (success) {
      connectionStatus = ConnectionStatus.connected;
      currentDevice = dev.copyWith(isConnected: true, pingMs: isWifiProto ? wifiService.pingMs : dev.pingMs);
      database.updateLastConnected(dev.id);
      _loadPairedProfiles();
      addTerminalLog("[${dev.protocol}] Connection established! Ping: ${isWifiProto ? wifiService.pingMs : 12} ms", LogType.system);
    } else {
      connectionStatus = ConnectionStatus.disconnected;
      currentDevice = dev.copyWith(isConnected: false);
      final errorMsg = isWifiProto
          ? (wifiService.lastError ?? "Wi-Fi connection failed to ${dev.ipAddress}.")
          : (bleService.lastError ?? "Connection failed to ${dev.name}. Check device power or pairing.");
      addTerminalLog("[${dev.protocol}] $errorMsg", LogType.error);
    }
    notifyListeners();
  }

  void disconnectDevice() {
    final dev = currentDevice;
    if (wifiService.isConnected) {
      wifiService.disconnect();
    }
    bleService.disconnect();
    connectionStatus = ConnectionStatus.disconnected;
    currentDevice = dev.copyWith(isConnected: false);
    addTerminalLog("[SYS] Disconnected from ${dev.name}", LogType.system);
    notifyListeners();
  }

  void toggleDeviceConnection(String id) {
    if (connectionStatus == ConnectionStatus.connected) {
      disconnectDevice();
    } else {
      final dev = nearbyDiscoveredDevices.firstWhere((d) => d.id == id, orElse: () => currentDevice);
      selectTargetDevice(dev);
      connectToTargetDevice();
    }
  }

  Future<void> forgetDevice(String id) async {
    await database.deleteProfile(id);
    await _loadPairedProfiles();
    if (currentDevice.id == id && currentDevice.isConnected) {
      disconnectDevice();
    }
    notifyListeners();
  }

  /// Explicitly connect to an ESP device via Wi-Fi (SoftAP or Local Network)
  Future<bool> connectWifi({
    required String host,
    int port = 8080,
    WifiMode mode = WifiMode.softAp,
    String? name,
  }) async {
    connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    final isAp = mode == WifiMode.softAp;
    final devName = name ?? (isAp ? "ESP32 Hotspot (SoftAP)" : "ESP32 (LAN)");
    final proto = isAp ? "Wi-Fi (SoftAP)" : "Wi-Fi (LAN)";
    addTerminalLog("[Wi-Fi] Connecting to $devName at http://$host:$port [$proto]...", LogType.system);

    final success = await wifiService.connect(host: host, port: port, mode: mode, name: devName);
    if (success) {
      final newDev = RoboticDevice(
        id: "wifi-${host.replaceAll('.', '-')}",
        name: devName,
        macAddress: "IP: $host:$port",
        ipAddress: host,
        protocol: proto,
        rssi: isAp ? -35 : -55,
        isConnected: true,
        pingMs: wifiService.pingMs,
        deviceType: "Rover",
      );
      selectTargetDevice(newDev);
      connectionStatus = ConnectionStatus.connected;
      currentDevice = newDev;
      addTerminalLog("[Wi-Fi] Connected to $devName ($host:$port) successfully!", LogType.system);
    } else {
      connectionStatus = ConnectionStatus.disconnected;
      currentDevice = currentDevice.copyWith(isConnected: false);
      addTerminalLog("[Wi-Fi] ${wifiService.lastError ?? 'Connection to ESP device timed out.'}", LogType.error);
    }
    notifyListeners();
    return success;
  }

  Future<void> scanSubnet() async {
    isScanning = true;
    notifyListeners();
    addTerminalLog("[Wi-Fi] Scanning local subnet for ESP32 / ESP8266 devices...", LogType.system);
    await wifiService.scanSubnet();
    isScanning = wifiService.isScanningSubnet;
    notifyListeners();
  }

  // --- CAR CONTROLLER & DRIVING STATE ---
  double speedCap = 75.0; // percentage
  String driveMode = "NORM"; // "CRAWL", "NORM", "SPORT"
  String gear = "D"; // 'P', 'R', 'N', 'D'
  bool headlights = false;
  bool hornActive = false;
  bool emergencyBrake = false;
  bool danceMode = false;
  double throttle = 0.0; // -1.0 to 1.0
  double steering = 0.0; // -1.0 to 1.0
  String motionStatusText = "IDLE • STANDBY";

  void setSpeedCap(double val) {
    speedCap = val;
    if (val <= 40) {
      driveMode = "CRAWL";
    } else if (val <= 80) {
      driveMode = "NORM";
    } else {
      driveMode = "SPORT";
    }
    sendPayload("SPEED:${val.toInt()}\n");
    addTerminalLog(">>> SET_SPEED: ${val.toInt()}% [$driveMode]", LogType.tx);
    notifyListeners();
  }

  void setThrottle(double t) {
    throttle = t;
    _updateMotionText();
    notifyListeners();
  }

  void setSteering(double s) {
    steering = s;
    _updateMotionText();
    notifyListeners();
  }

  void _updateMotionText() {
    if (emergencyBrake) {
      motionStatusText = "EMERGENCY BRAKE ACTIVE";
    } else if (throttle > 0.1) {
      motionStatusText = "FORWARD • ${(throttle * 100).toInt()}%";
    } else if (throttle < -0.1) {
      motionStatusText = "REVERSE • ${(-throttle * 100).toInt()}%";
    } else if (steering.abs() > 0.1) {
      motionStatusText = steering > 0 ? "RIGHT TURN" : "LEFT TURN";
    } else {
      motionStatusText = "IDLE • STANDBY";
    }
  }

  bool useNumericMotionCommands = true; // Default true: 1=Forward, 2=Backward, 3=Left, 4=Right, 0=Stop

  void toggleMotionCommandProtocol() {
    useNumericMotionCommands = !useNumericMotionCommands;
    addTerminalLog(">>> PROTOCOL_SWITCH: ${useNumericMotionCommands ? 'NUMERIC (1/2/3/4/0)' : 'STANDARD (F/B/L/R/S)'}", LogType.system);
    notifyListeners();
  }

  void sendCarMotionCommand(String cmd) {
    String out = cmd;
    if (useNumericMotionCommands) {
      switch (cmd.trim()) {
        case 'F':
        case 'U':
          out = '1';
          break;
        case 'B':
        case 'D':
          out = '2';
          break;
        case 'L':
          out = '3';
          break;
        case 'R':
          out = '4';
          break;
        case 'S':
        case '0':
          out = '0';
          break;
        default:
          out = cmd;
      }
    }
    sendPayload(out.endsWith('\n') ? out : "$out\n");
  }

  void toggleHeadlights() {
    headlights = !headlights;
    relays[0] = headlights; // sync with switch panel Ch 1
    sendPayload(headlights ? "1\n" : "0\n");
    addTerminalLog(">>> SET_LIGHT=${headlights ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void setHorn(bool active) {
    hornActive = active;
    relays[3] = active; // sync with Buzzer Ch 4
    sendPayload(active ? "H" : "h");
    addTerminalLog(">>> HORN=${active ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void triggerEmergencyBrake() {
    emergencyBrake = !emergencyBrake;
    if (emergencyBrake) {
      throttle = 0;
      steering = 0;
      danceMode = false;
      motionStatusText = "EMERGENCY BRAKE ACTIVE";
      sendCarMotionCommand("S");
      addTerminalLog(">>> [E-STOP] MOTORS HALTED IMMEDIATELY", LogType.error);
    } else {
      motionStatusText = "IDLE • STANDBY";
    }
    notifyListeners();
  }

  void toggleDanceMode() {
    danceMode = !danceMode;
    if (danceMode) {
      emergencyBrake = false;
      motionStatusText = "DANCE CHOREOGRAPHY ACTIVE";
      sendPayload("X\n");
      addTerminalLog(">>> EXEC_ROUTINE: CHOREO_DANCE_01", LogType.tx);
    } else {
      motionStatusText = "IDLE • STANDBY";
      sendCarMotionCommand("S");
    }
    notifyListeners();
  }

  // --- VIRTUAL KEYPAD ---
  String keypadDisplay = "READY";
  List<String> keypadHistory = ["A: SCAN", "1: FWD_10CM", "5: CENTER_ALL"];

  void pressKeypad(String key) {
    if (key == "*") {
      keypadDisplay = "";
      sendPayload("*\n");
    } else if (key == "#") {
      if (keypadDisplay.isNotEmpty) {
        keypadHistory.insert(0, keypadDisplay);
        if (keypadHistory.length > 20) keypadHistory.removeLast();
        addTerminalLog(">>> KEYPAD_CMD: $keypadDisplay", LogType.tx);
        sendPayload("$keypadDisplay#\n");
        keypadDisplay = "SENT: $keypadDisplay";
      }
    } else {
      sendPayload("$key\n");
      if (keypadDisplay == "READY" || keypadDisplay.startsWith("SENT")) {
        keypadDisplay = key;
      } else {
        keypadDisplay += key;
      }
    }
    notifyListeners();
  }

  // --- TELEMETRY STATE ---
  double batteryVoltage = 8.4;
  double batteryPercentage = 92.0;
  double motorCurrent = 1.65; // Amps
  double coreTemperature = 38.4; // Celsius
  double pitchAngle = -1.8; // degrees
  double rollAngle = 3.2; // degrees
  double yawAngle = 142.0; // degrees
  int linkLatency = 12; // ms
  double proximityDistance = 48.0; // cm
  double get ultrasonicDistance => proximityDistance;
  int get batteryPercent => batteryPercentage.toInt();

  void addLog(LogType type, String msg) => addTerminalLog(msg, type);

  Timer? _telemetryTimer;
  void _startSimulatedTelemetry() {
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!currentDevice.isConnected) return;
      // Slight subtle realistic jitter
      batteryVoltage = 8.38 + (timer.tick % 5) * 0.01;
      coreTemperature = 38.0 + (timer.tick % 7) * 0.1;
      motorCurrent = (throttle != 0 || steering != 0) ? 2.45 + (timer.tick % 4) * 0.2 : 0.42;
      linkLatency = 11 + (timer.tick % 4);
      notifyListeners();
    });
  }

  void stopSimulatedTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  // --- LED / LAMP STATE ---
  bool lampPower = false;
  Color lampColor = const Color(0xFF00E5FF);
  double lampBrightness = 85.0; // 0 - 100
  String lampMode = "Solid"; // "Solid", "Pulse", "Strobe", "Rainbow", "Police"
  double lampSpeed = 50.0;

  void toggleLampPower() {
    lampPower = !lampPower;
    sendPayload(lampPower ? "RGB_POWER:1\n" : "RGB_POWER:0\n");
    addTerminalLog(">>> RGB_POWER=${lampPower ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void setLampColor(Color c) {
    lampColor = c;
    lampPower = true;
    final hex = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    sendPayload("RGB_COLOR:$hex\n");
    addTerminalLog(">>> RGB_COLOR=$hex", LogType.tx);
    notifyListeners();
  }

  void setLampBrightness(double b) {
    lampBrightness = b;
    sendPayload("RGB_BRIGHT:${b.toInt()}\n");
    notifyListeners();
  }

  void setLampMode(String m) {
    lampMode = m;
    sendPayload("RGB_MODE:$m\n");
    notifyListeners();
  }

  // --- 8-CHANNEL SWITCH PANEL ---
  List<bool> relays = [
    false, // Ch 1: Headlights
    false, // Ch 2: Underglow Neopixels
    true,  // Ch 3: Auxiliary 5V Rail
    false, // Ch 4: Warning Buzzer
    true,  // Ch 5: FPV Camera Pan/Tilt
    false, // Ch 6: High-Torque Gearbox Solenoid
    true,  // Ch 7: Cooling Fan
    false, // Ch 8: Targeting Laser Pointer
  ];

  final List<String> relayNames = [
    "Headlights (High Beam)",
    "Underglow Neopixels",
    "Auxiliary 5V Power Rail",
    "Audible Alert Siren / Buzzer",
    "FPV Camera Gimbal Servos",
    "Gearbox High-Torque Lock",
    "Active Cooling Fan",
    "Targeting Red Laser Pointer",
  ];

  void toggleRelay(int index) {
    relays[index] = !relays[index];
    if (index == 0) headlights = relays[0];
    final charCode = relays[index] ? (97 + index) : (65 + index); // 'a'-'h' for ON, 'A'-'H' for OFF
    final relayChar = String.fromCharCode(charCode);
    sendPayload("$relayChar\n");
    addTerminalLog(">>> RELAY_SET(CH${index + 1}, ${relays[index] ? 1 : 0}) [$relayChar]", LogType.tx);
    notifyListeners();
  }

  void setAllRelays(bool state) {
    for (int i = 0; i < relays.length; i++) {
      relays[i] = state;
    }
    headlights = state;
    sendPayload(state ? "RELAY_ALL_ON\n" : "RELAY_ALL_OFF\n");
    addTerminalLog(">>> MASTER_RELAYS=${state ? 'ALL_ON' : 'ALL_OFF'}", LogType.tx);
    notifyListeners();
  }

  // --- SERIAL TERMINAL / CLI ---
  List<TerminalLog> logs = [];
  int baudRate = 115200;
  bool autoScroll = true;

  void _initTerminalLogs() {
    logs = [];
  }

  void addTerminalLog(String msg, LogType type) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond).toString().padLeft(3, '0')}";
    logs.add(TerminalLog(timestamp: timeStr, message: msg, type: type));
    if (logs.length > 200) logs.removeAt(0);
    notifyListeners();
  }

  void sendTerminalCommand(String cmd) {
    if (cmd.trim().isEmpty) return;
    addTerminalLog(cmd.trim(), LogType.tx);
    sendPayload("${cmd.trim()}\n");
  }

  void clearTerminal() {
    logs.clear();
    notifyListeners();
  }

  // --- ROBOTIC ARM (6-DOF) ---
  Map<String, double> armAngles = {
    'A': 90.0,  // Base Axis 1
    'B': 45.0,  // Shoulder Axis 2
    'C': 120.0, // Elbow Axis 3
    'D': 90.0,  // Wrist Pitch Axis 4
    'E': 0.0,   // Wrist Roll Axis 5
    'F': 55.0,  // Gripper Claw Axis 6
  };

  void setArmAngle(String axis, double angle) {
    armAngles[axis] = angle;
    sendPayload("$axis${angle.toInt()}\n");
    notifyListeners();
  }

  void resetAllArmServos() {
    armAngles = {
      'A': 90.0,
      'B': 90.0,
      'C': 90.0,
      'D': 90.0,
      'E': 90.0,
      'F': 0.0,
    };
    sendPayload("A90\nB90\nC90\n");
    addTerminalLog(">>> ARM_RESET(A90, B90, C90)", LogType.tx);
    notifyListeners();
  }

  void setArmPose(String poseName) {
    if (poseName == "Home") {
      armAngles = {'A': 90.0, 'B': 90.0, 'C': 90.0, 'D': 90.0, 'E': 90.0, 'F': 0.0};
    } else if (poseName == "Pick") {
      armAngles = {'A': 90.0, 'B': 140.0, 'C': 45.0, 'D': 110.0, 'E': 0.0, 'F': 100.0};
    } else if (poseName == "Place") {
      armAngles = {'A': 170.0, 'B': 130.0, 'C': 50.0, 'D': 95.0, 'E': 45.0, 'F': 10.0};
    } else if (poseName == "Wave") {
      armAngles = {'A': 90.0, 'B': 30.0, 'C': 160.0, 'D': 45.0, 'E': 80.0, 'F': 50.0};
    }
    sendPayload("ARM_PRESET:$poseName\n");
    addTerminalLog(">>> ARM_EXEC_PRESET: $poseName", LogType.tx);
    notifyListeners();
  }

  // --- GYRO / TILT-TO-STEER ---
  bool gyroEnabled = true;
  double gyroSensitivity = 1.2;
  double gyroDeadzone = 5.0; // degrees
  double phonePitch = 0.0;
  double phoneRoll = 0.0;
  double phoneYaw = 0.0;

  void toggleGyro() {
    gyroEnabled = !gyroEnabled;
    addTerminalLog(">>> GYRO_STEER_ACTIVE=${gyroEnabled ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void calibrateGyroHorizon() {
    phonePitch = 0.0;
    phoneRoll = 0.0;
    addTerminalLog(">>> GYRO_ZERO_CALIBRATED", LogType.tx);
    notifyListeners();
  }

  // --- VOICE CONTROL ---
  bool isVoiceListening = false;
  String lastVoiceTranscript = "Move forward at half speed";
  double voiceConfidence = 0.94;
  List<String> voiceHistory = [
    "Move forward at half speed",
    "Turn lights on",
    "Full stop",
    "Start dance mode",
  ];

  String? executeVoiceCommand(String rawTranscript, {double confidence = 0.95}) {
    final text = rawTranscript.toLowerCase().trim();
    if (text.isEmpty) return null;

    lastVoiceTranscript = rawTranscript;
    voiceConfidence = confidence;
    if (!voiceHistory.contains(rawTranscript)) {
      voiceHistory.insert(0, rawTranscript);
      if (voiceHistory.length > 20) voiceHistory.removeLast();
    }

    String? executedAction;
    String? btCmd;

    // RGB Lamp / RGB Lights
    if (text.contains("rgb") && (text.contains("on") || text.contains("start") || text.contains("enable"))) {
      lampPower = true;
      relays[1] = true;
      btCmd = "RGB_POWER:1";
      executedAction = "RGB Lamp ON";
    } else if (text.contains("rgb") && (text.contains("off") || text.contains("of") || text.contains("stop") || text.contains("disable"))) {
      lampPower = false;
      relays[1] = false;
      btCmd = "RGB_POWER:0";
      executedAction = "RGB Lamp OFF";
    } else if (text.contains("rgb") && text.contains("red")) {
      setLampColor(const Color(0xFFFF0000));
      executedAction = "RGB Color: Red";
    } else if (text.contains("rgb") && text.contains("green")) {
      setLampColor(const Color(0xFF00FF00));
      executedAction = "RGB Color: Green";
    } else if (text.contains("rgb") && text.contains("blue")) {
      setLampColor(const Color(0xFF0000FF));
      executedAction = "RGB Color: Blue";
    } else if (text.contains("forward") || text.contains("ahead") || text.contains("front") || text.contains("straight")) {
      throttle = 1.0;
      steering = 0.0;
      motionStatusText = "FORWARD • 100%";
      btCmd = "F";
      executedAction = "Move Forward (F)";
    } else if (text.contains("backward") || text.contains("back") || text.contains("reverse")) {
      throttle = -1.0;
      steering = 0.0;
      motionStatusText = "REVERSE • 100%";
      btCmd = "B";
      executedAction = "Reverse (B)";
    } else if (text.contains("left")) {
      throttle = 0.0;
      steering = -1.0;
      motionStatusText = "LEFT TURN";
      btCmd = "L";
      executedAction = "Turn Left (L)";
    } else if (text.contains("right")) {
      throttle = 0.0;
      steering = 1.0;
      motionStatusText = "RIGHT TURN";
      btCmd = "R";
      executedAction = "Turn Right (R)";
    } else if (text.contains("stop") || text.contains("halt") || text.contains("freeze") || text.contains("brake") || text.contains("pause")) {
      throttle = 0.0;
      steering = 0.0;
      danceMode = false;
      motionStatusText = "IDLE • STANDBY";
      btCmd = "S";
      executedAction = "Full Stop (S)";
    } else if (text.contains("light on") || text.contains("lights on") || text.contains("headlight on") || text.contains("turn on light") || text.contains("turn on the light") || text.contains("turn on lights") || text.contains("turn on the lights")) {
      headlights = true;
      relays[0] = true;
      btCmd = "1";
      executedAction = "Lights ON (1)";
    } else if (text.contains("light off") || text.contains("lights off") || text.contains("headlight off") || text.contains("turn off light") || text.contains("turn off the light") || text.contains("turn off lights") || text.contains("turn off the lights")) {
      headlights = false;
      relays[0] = false;
      btCmd = "0";
      executedAction = "Lights OFF (0)";
    } else if (text.contains("horn") || text.contains("beep") || text.contains("honk")) {
      hornActive = true;
      relays[3] = true;
      btCmd = "H";
      executedAction = "Horn Sounding (H)";
      Future.delayed(const Duration(milliseconds: 1500), () {
        hornActive = false;
        relays[3] = false;
        sendPayload("h\n");
        notifyListeners();
      });
    } else if (text.contains("dance") || text.contains("party") || text.contains("celebrate")) {
      danceMode = true;
      motionStatusText = "DANCE CHOREOGRAPHY ACTIVE";
      btCmd = "X";
      executedAction = "Dance Mode (X)";
    } else if (text.contains("faster") || text.contains("fast") || text.contains("full speed") || text.contains("high speed")) {
      setSpeedCap(100.0);
      executedAction = "Speed 100%";
    } else if (text.contains("slow") || text.contains("half speed") || text.contains("slow down")) {
      setSpeedCap(50.0);
      executedAction = "Speed 50%";
    } else {
      executedAction = null;
    }

    if (btCmd != null) {
      sendPayload("$btCmd\n");
      addTerminalLog(">>> VOICE_CMD: '$rawTranscript' -> [$btCmd] ($executedAction)", LogType.tx);
    } else {
      addTerminalLog("[VOICE] Unrecognized command: '$rawTranscript'", LogType.error);
    }

    notifyListeners();
    return executedAction;
  }

  // --- ESP32-CAM ---
  String camMode = "AP"; // "AP" or "Router"
  String camIp = "192.168.4.1";
  bool isCamStreaming = true;
  bool camFlash = false;
  double camFlashBrightness = 60.0;
  bool faceDetection = true;
  double camPan = 90.0;
  double camTilt = 45.0;
  List<String> capturedPhotos = [];

  void toggleCamMode(String mode) {
    camMode = mode;
    camIp = (mode == "AP") ? "192.168.4.1" : "192.168.1.184";
    notifyListeners();
  }

  void toggleCamFlash() {
    camFlash = !camFlash;
    notifyListeners();
  }

  void captureCamPhoto() {
    final photoName = "IMG_ESP32_${DateTime.now().millisecondsSinceEpoch}.jpg";
    capturedPhotos.insert(0, photoName);
    addTerminalLog(">>> ESP32_CAM: Snapshot saved to $photoName", LogType.rx);
    notifyListeners();
  }

  // --- USER PROFILE & SETTINGS ---
  String userName = "Alex Harrison";
  String userRole = "Lead Robotics Operator";
  int connectedRobotsCount = 12;
  int hoursLogged = 148;
  double linkReliability = 99.4;

  bool hapticVibration = true;
  int telemetryFrequencyHz = 20;
  bool invertY = false;

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }
}
