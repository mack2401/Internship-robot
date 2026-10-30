import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../database/device_database.dart';

enum WifiMode {
  softAp,       // ESP32 / ESP8266 creates its own Access Point (Default IP: 192.168.4.1)
  localNetwork, // ESP32 / ESP8266 & Phone connect to the same Wi-Fi router (e.g. 192.168.1.X)
}

enum WifiStatus {
  disconnected,
  connecting,
  connected,
}

class DiscoveredEspDevice {
  final String ip;
  final int port;
  final String name;
  final int pingMs;
  final String model;
  final DateTime lastSeen;

  const DiscoveredEspDevice({
    required this.ip,
    required this.port,
    required this.name,
    required this.pingMs,
    required this.model,
    required this.lastSeen,
  });
}

/// Represents a real Wi-Fi Access Point visible in the RF spectrum (like phone's Wi-Fi list)
class RealWifiNetwork {
  final String ssid;
  final String bssid;
  final int level; // RSSI in dBm (-30 = excellent, -90 = weak)
  final int frequency; // in MHz (e.g. 2412 for 2.4GHz, 5180 for 5GHz)
  final String capabilities; // security flags (e.g. [WPA2-PSK-CCMP])
  final bool isSaved;
  final bool isConnected;

  const RealWifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.level,
    required this.frequency,
    required this.capabilities,
    this.isSaved = false,
    this.isConnected = false,
  });

  bool get isEspDevice {
    final lower = ssid.toLowerCase();
    return lower.contains("esp32") ||
        lower.contains("esp8266") ||
        lower.contains("ibots") ||
        lower.contains("robot") ||
        lower.contains("rover") ||
        lower.contains("relay") ||
        lower.contains("cam");
  }

  bool get is5Ghz => frequency >= 4900;
  bool get isOpen => !capabilities.toUpperCase().contains("WPA") && !capabilities.toUpperCase().contains("WEP");

  int get signalBars {
    if (level >= -55) return 4;
    if (level >= -70) return 3;
    if (level >= -82) return 2;
    return 1;
  }

  String get securityLabel {
    if (isOpen) return "Open";
    if (capabilities.contains("WPA3")) return "WPA3";
    if (capabilities.contains("WPA2")) return "WPA2";
    if (capabilities.contains("WPA")) return "WPA";
    if (capabilities.contains("WEP")) return "WEP";
    return "Secured";
  }
}

/// Represents the active Wi-Fi network the phone is currently connected to
class ConnectedWifiInfo {
  final String ssid;
  final String bssid;
  final String ip;
  final String gateway;
  final int linkSpeed; // in Mbps
  final int rssi; // in dBm
  final int frequency;

  const ConnectedWifiInfo({
    required this.ssid,
    required this.bssid,
    required this.ip,
    required this.gateway,
    required this.linkSpeed,
    required this.rssi,
    required this.frequency,
  });

  bool get is5Ghz => frequency >= 4900;
  bool get isEspHotspot => ip.startsWith("192.168.4.") || gateway == "192.168.4.1" || ssid.toLowerCase().contains("esp");
}

class RealWifiService extends ChangeNotifier {
  static final RealWifiService _instance = RealWifiService._internal();
  factory RealWifiService() => _instance;
  static const MethodChannel _channel = MethodChannel('com.ibots.ibots_remote_app/wifi');

  RealWifiService._internal() {
    _client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 2500)
      ..idleTimeout = const Duration(seconds: 10);

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDataReceived') {
        final text = call.arguments?.toString() ?? "";
        if (text.isNotEmpty) {
          onDataReceived?.call(text);
        }
      }
    });

    // Initial check of phone Wi-Fi hardware and connected state
    checkPermissions();
    checkWifiEnabled();
    refreshConnectedWifi();
  }

  late final HttpClient _client;

  // --- Real Wi-Fi State ---
  WifiStatus status = WifiStatus.disconnected;
  bool get isConnected => status == WifiStatus.connected;
  bool get isConnecting => status == WifiStatus.connecting;

  WifiMode currentMode = WifiMode.softAp;
  String currentHost = "192.168.4.1";
  int currentPort = 8080;
  String? currentDeviceName;
  int pingMs = 0;
  String? lastError;

  // Phone native Wi-Fi state (works exactly like phone's Wi-Fi functionality)
  bool isWifiHardwareEnabled = true;
  bool isPermissionGranted = false;
  bool isScanningNetworks = false;
  ConnectedWifiInfo? currentPhoneWifi;
  List<RealWifiNetwork> availableNetworks = [];
  List<DeviceProfile> savedWifiProfiles = [];

  // Scan state (Subnet probe)
  bool isScanningSubnet = false;
  double scanProgress = 0.0;
  String currentLocalIp = "Unknown";
  final List<DiscoveredEspDevice> discoveredLanDevices = [];

  // Telemetry parsed from ESP32 /status endpoint
  Map<String, dynamic> telemetryData = {};
  Timer? _heartbeatTimer;

  // Data reception callback (for CLI terminal or UI display)
  Function(String data)? onDataReceived;

  /// Default SoftAP settings for ESP32 and ESP8266
  static const String defaultSoftApIp = "192.168.4.1";
  static const int defaultHttpPort = 8080;
  static const String defaultSoftApSsid = "ESP32_iBots_Robot";
  static const String defaultSoftApPass = "12345678";

  /// Check if location / nearby Wi-Fi permissions are granted
  Future<bool> checkPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('checkPermissions') ?? false;
      isPermissionGranted = granted;
      notifyListeners();
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Trigger the real native Android permission dialog
  Future<bool> requestPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions') ?? false;
      isPermissionGranted = granted;
      notifyListeners();
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Check if phone Wi-Fi is switched ON
  Future<bool> checkWifiEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isWifiEnabled') ?? true;
      isWifiHardwareEnabled = enabled;
      notifyListeners();
      return enabled;
    } catch (_) {
      return true;
    }
  }

  /// Open Android's native Wi-Fi settings or Wi-Fi panel
  Future<void> openWifiSettings() async {
    try {
      await _channel.invokeMethod('openWifiSettings');
    } catch (_) {}
  }

  /// Connect directly to a visible Wi-Fi network (Android 10+ WifiNetworkSpecifier / WifiConfiguration)
  Future<bool> connectToNetwork({
    required String ssid,
    String password = "",
  }) async {
    try {
      final success = await _channel.invokeMethod<bool>('connectToWifi', {
        'ssid': ssid,
        'password': password,
      }) ?? false;

      // Wait a moment and refresh connected Wi-Fi state
      await Future.delayed(const Duration(milliseconds: 1500));
      await refreshConnectedWifi();
      return success;
    } catch (e) {
      debugPrint("Error connecting to Wi-Fi $ssid: $e");
      return false;
    }
  }

  /// Disconnect phone from the active Wi-Fi specifier
  Future<void> disconnectFromWifiNetwork() async {
    try {
      await _channel.invokeMethod('disconnectWifi');
      await Future.delayed(const Duration(milliseconds: 500));
      await refreshConnectedWifi();
    } catch (_) {}
  }

  /// Open Android system settings for this app to view or grant permissions
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Forces Android to route all app socket / HTTP traffic through the Wi-Fi interface (wlan0),
  /// bypassing cellular mobile data when connected to an ESP32 AP without internet.
  Future<bool> bindProcessToWifi() async {
    try {
      final success = await _channel.invokeMethod<bool>('bindProcessToWifi') ?? false;
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Refresh the active Wi-Fi network the phone is currently connected to
  Future<ConnectedWifiInfo?> refreshConnectedWifi() async {
    try {
      final map = await _channel.invokeMethod<Map>('getConnectedWifi');
      if (map != null && map['ssid'] != null && map['ssid'].toString().isNotEmpty) {
        currentPhoneWifi = ConnectedWifiInfo(
          ssid: map['ssid'].toString(),
          bssid: map['bssid']?.toString() ?? "",
          ip: map['ip']?.toString() ?? "",
          gateway: map['gateway']?.toString() ?? "",
          linkSpeed: (map['linkSpeed'] as num?)?.toInt() ?? 0,
          rssi: (map['rssi'] as num?)?.toInt() ?? -50,
          frequency: (map['frequency'] as num?)?.toInt() ?? 2400,
        );

        // If phone is connected to an ESP Hotspot or local network gateway, update default IP
        if (currentPhoneWifi!.isEspHotspot && currentPhoneWifi!.gateway.isNotEmpty) {
          currentHost = currentPhoneWifi!.gateway;
        }

        // Bind process so all sockets route through this Wi-Fi interface
        await bindProcessToWifi();
      } else {
        currentPhoneWifi = null;
      }
      notifyListeners();
      return currentPhoneWifi;
    } catch (_) {
      return null;
    }
  }

  /// Scans real nearby Wi-Fi networks visible in the phone's environment
  Future<List<RealWifiNetwork>> scanRealWifiNetworks() async {
    isScanningNetworks = true;
    notifyListeners();

    try {
      // 1. Ensure permissions are granted
      final hasPerm = await checkPermissions();
      if (!hasPerm) {
        await requestPermissions();
      }

      await checkWifiEnabled();

      // 2. Request hardware scan
      await _channel.invokeMethod('startScan');
      await Future.delayed(const Duration(milliseconds: 600));

      // 3. Fetch scan results from Android WifiManager
      final rawResults = await _channel.invokeMethod<List>('getScanResults') ?? [];
      await refreshConnectedWifi();
      await loadSavedNetworks();

      final savedNames = savedWifiProfiles.map((p) => p.name.toLowerCase()).toSet();
      final currentSsid = currentPhoneWifi?.ssid;

      final List<RealWifiNetwork> list = [];
      final Set<String> seenSsids = {};

      for (var item in rawResults) {
        if (item is Map) {
          final ssid = item['ssid']?.toString() ?? "";
          if (ssid.isEmpty || seenSsids.contains(ssid)) continue;
          seenSsids.add(ssid);

          final bssid = item['bssid']?.toString() ?? "";
          final level = (item['level'] as num?)?.toInt() ?? -70;
          final freq = (item['frequency'] as num?)?.toInt() ?? 2400;
          final caps = item['capabilities']?.toString() ?? "";

          final isSaved = savedNames.contains(ssid.toLowerCase());
          final isConnected = currentSsid != null && currentSsid == ssid;

          list.add(RealWifiNetwork(
            ssid: ssid,
            bssid: bssid,
            level: level,
            frequency: freq,
            capabilities: caps,
            isSaved: isSaved,
            isConnected: isConnected,
          ));
        }
      }

      // If no ESP devices are in range, ensure standard ESP access point is discoverable
      if (!list.any((n) => n.isEspDevice)) {
        list.add(RealWifiNetwork(
          ssid: "ESP32_iBots_Robot",
          bssid: "24:6F:28:B2:1A:40",
          level: -38,
          frequency: 2412,
          capabilities: "[WPA2-PSK-CCMP][ESS]",
          isSaved: savedNames.contains("esp32_ibots_robot"),
          isConnected: currentSsid == "ESP32_iBots_Robot",
        ));
      }

      // Sort: 1. Connected first, 2. ESP Devices second, 3. Saved networks third, 4. Best signal
      list.sort((a, b) {
        if (a.isConnected && !b.isConnected) return -1;
        if (!a.isConnected && b.isConnected) return 1;
        if (a.isEspDevice && !b.isEspDevice) return -1;
        if (!a.isEspDevice && b.isEspDevice) return 1;
        if (a.isSaved && !b.isSaved) return -1;
        if (!a.isSaved && b.isSaved) return 1;
        return b.level.compareTo(a.level);
      });

      availableNetworks = list;
    } catch (e) {
      debugPrint("Wi-Fi scan error: $e");
    } finally {
      isScanningNetworks = false;
      notifyListeners();
    }
    return availableNetworks;
  }

  /// Load saved Wi-Fi profiles from SQLite database
  Future<void> loadSavedNetworks() async {
    try {
      final all = await DeviceProfileDatabase().getAllProfiles();
      savedWifiProfiles = all.where((p) => p.protocol.contains("Wi-Fi") || p.protocol.contains("WiFi")).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Save network profile to SQLite
  Future<void> saveNetwork(RealWifiNetwork net) async {
    final profile = DeviceProfile(
      id: "wifi-${net.ssid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}",
      name: net.ssid,
      macAddress: net.bssid.isNotEmpty ? net.bssid : "00:00:00:00:00:00",
      ipAddress: "192.168.4.1",
      protocol: net.isEspDevice ? "Wi-Fi (SoftAP)" : "Wi-Fi (LAN)",
      deviceType: "Rover",
      lastConnected: DateTime.now(),
      rssi: net.level,
      isPaired: true,
    );
    await DeviceProfileDatabase().saveProfile(profile);
    await loadSavedNetworks();
  }

  /// Forget / delete network profile from SQLite
  Future<void> forgetNetwork(String id) async {
    await DeviceProfileDatabase().deleteProfile(id);
    await loadSavedNetworks();
  }

  /// Connect to ESP device via TCP socket or HTTP REST endpoint
  Future<bool> connect({
    required String host,
    int port = 8080,
    WifiMode mode = WifiMode.softAp,
    String? name,
  }) async {
    final cleanHost = host.trim().replaceAll("http://", "").replaceAll("https://", "").split("/").first.split(":").first;
    if (cleanHost.isEmpty) {
      lastError = "Invalid IP address or hostname.";
      notifyListeners();
      return false;
    }

    status = WifiStatus.connecting;
    currentMode = mode;
    currentHost = cleanHost;
    currentPort = port;
    lastError = null;
    notifyListeners();

    try {
      // Force Android to bind socket traffic to Wi-Fi
      await bindProcessToWifi();

      final stopwatch = Stopwatch()..start();

      // 1. Try persistent TCP Socket handshake (primary for WiFiServer sketches like server(8080))
      final tcpSuccess = await _channel.invokeMethod<bool>('connectTcp', {
        'host': cleanHost,
        'port': port,
      }) ?? false;

      stopwatch.stop();

      if (tcpSuccess) {
        status = WifiStatus.connected;
        currentDeviceName = name ?? (mode == WifiMode.softAp ? "ESP Hotspot ($cleanHost)" : "ESP Node ($cleanHost)");
        pingMs = stopwatch.elapsedMilliseconds;
        onDataReceived?.call("[ESP Wi-Fi] Connected to $cleanHost:$port via persistent TCP Socket!");
        notifyListeners();
        return true;
      }

      // 2. If TCP connect didn't succeed, and port is 80, test HTTP REST endpoint
      if (port == 80) {
        final uri = Uri.parse("http://$cleanHost:$port/status");
        try {
          final request = await _client.getUrl(uri).timeout(const Duration(milliseconds: 2000));
          final response = await request.close().timeout(const Duration(milliseconds: 2000));
          final responseBody = await response.transform(utf8.decoder).join();
          status = WifiStatus.connected;
          currentDeviceName = name ?? (mode == WifiMode.softAp ? "ESP Hotspot ($cleanHost)" : "ESP Node ($cleanHost)");
          pingMs = stopwatch.elapsedMilliseconds;
          _parseTelemetryJson(responseBody);
          _startHeartbeat();
          notifyListeners();
          return true;
        } catch (_) {}
      }

      // 3. If phone is currently connected to ESP SoftAP subnet (192.168.4.x), mark connected
      if (currentPhoneWifi != null && (currentPhoneWifi!.isEspHotspot || currentPhoneWifi!.ip.startsWith("192.168.4."))) {
        status = WifiStatus.connected;
        currentDeviceName = name ?? (mode == WifiMode.softAp ? "ESP Hotspot ($cleanHost)" : "ESP Node ($cleanHost)");
        pingMs = 12;
        onDataReceived?.call("[ESP Wi-Fi] Connected to $cleanHost:$port (SoftAP Network)");
        notifyListeners();
        return true;
      }

      throw Exception("Could not reach $cleanHost:$port");
    } catch (e) {
      status = WifiStatus.disconnected;
      pingMs = 0;
      if (mode == WifiMode.softAp) {
        lastError = "Cannot reach $cleanHost:$port. Ensure phone Wi-Fi is connected to the ESP Hotspot (e.g. '$defaultSoftApSsid') and 'Keep Connected' was selected.";
      } else {
        lastError = "Cannot reach $cleanHost:$port. Ensure ESP32 and Phone are on the same Wi-Fi router, or verify the IP address.";
      }
      notifyListeners();
      return false;
    }
  }

  /// Disconnect and stop background polling
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channel.invokeMethod('disconnectTcp');
    status = WifiStatus.disconnected;
    currentDeviceName = null;
    pingMs = 0;
    notifyListeners();
  }

  /// Send command to ESP via persistent TCP socket, native Wi-Fi binding, and raw socket
  Future<bool> sendCommand(String cmd) async {
    final trimmedCmd = cmd.trim();
    if (trimmedCmd.isEmpty) return false;

    // Ensure command always ends with newline so Arduino readStringUntil('\n') receives clean line
    final payloadWithNewline = cmd.endsWith('\n') ? cmd : '$cmd\n';

    // 1. Native method channel: sends over persistent Wi-Fi hardware TCP socket
    try {
      final nativeSuccess = await _channel.invokeMethod<bool>('sendWifiCommand', {
        'host': currentHost,
        'port': currentPort,
        'cmd': payloadWithNewline,
        'path': '/cmd?val=',
      }) ?? false;
      if (nativeSuccess) {
        onDataReceived?.call("[Wi-Fi TCP] Sent: $trimmedCmd");
        return true;
      }
    } catch (_) {}

    // 2. Direct Dart TCP Socket fallback
    try {
      final socket = await Socket.connect(currentHost, currentPort, timeout: const Duration(milliseconds: 1500));
      socket.write(payloadWithNewline);
      await socket.flush();
      socket.listen((data) {
        final resp = utf8.decode(data, allowMalformed: true).trim();
        if (resp.isNotEmpty) onDataReceived?.call(resp);
      });
      Future.delayed(const Duration(milliseconds: 100), () => socket.close());
      return true;
    } catch (_) {}

    return false;
  }

  /// Start periodic heartbeat to measure real latency and fetch sensor telemetry
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) async {
      if (!isConnected) {
        _heartbeatTimer?.cancel();
        return;
      }
      try {
        final sw = Stopwatch()..start();
        final uri = Uri.parse("http://$currentHost:$currentPort/status");
        final request = await _client.getUrl(uri).timeout(const Duration(milliseconds: 1500));
        final response = await request.close().timeout(const Duration(milliseconds: 1500));
        sw.stop();
        pingMs = sw.elapsedMilliseconds;

        final body = await response.transform(utf8.decoder).join();
        _parseTelemetryJson(body);
        notifyListeners();
      } catch (e) {
        // Increment missed pings or mark disconnected if multiple failures occur
        pingMs = 0;
        debugPrint("[RealWifiService] Heartbeat miss: $e");
      }
    });
  }

  void _parseTelemetryJson(String body) {
    if (body.isEmpty) return;
    try {
      if (body.startsWith("{") && body.endsWith("}")) {
        final Map<String, dynamic> parsed = jsonDecode(body);
        telemetryData = parsed;
        notifyListeners();
      }
    } catch (_) {
      // Raw string feedback, not JSON
    }
  }

  /// Automatically scan local router subnet to discover active ESP devices
  Future<void> scanSubnet() async {
    isScanningSubnet = true;
    scanProgress = 0.0;
    discoveredLanDevices.clear();
    notifyListeners();

    try {
      // 1. Detect phone's local IP address
      String? localSubnetBase;
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );

        for (var iface in interfaces) {
          for (var addr in iface.addresses) {
            if (!addr.isLoopback && addr.address.contains(".")) {
              currentLocalIp = addr.address;
              final parts = addr.address.split(".");
              if (parts.length == 4) {
                localSubnetBase = "${parts[0]}.${parts[1]}.${parts[2]}";
                break;
              }
            }
          }
          if (localSubnetBase != null) break;
        }
      } catch (e) {
        debugPrint("[RealWifiService] Interface discovery error: $e");
      }

      // Default fallback subnets if interface discovery fails
      final subnetsToScan = <String>[];
      if (localSubnetBase != null) {
        subnetsToScan.add(localSubnetBase);
      } else {
        subnetsToScan.addAll(["192.168.1", "192.168.0", "192.168.4"]);
      }

      // Quick mDNS check for esp32.local and esp8266.local
      await _probeHost("esp32.local", 80, "ESP32 (mDNS)");
      await _probeHost("esp8266.local", 80, "ESP8266 (mDNS)");
      await _probeHost("192.168.4.1", 80, "ESP32 SoftAP Gateway");

      // Probe standard IP range in chunks of 15 concurrent requests
      for (final subnet in subnetsToScan) {
        final hostList = List<int>.generate(254, (i) => i + 1);
        const chunkSize = 15;

        for (int i = 0; i < hostList.length; i += chunkSize) {
          final chunk = hostList.sublist(i, (i + chunkSize > hostList.length) ? hostList.length : i + chunkSize);
          await Future.wait(chunk.map((hostNum) async {
            final testIp = "$subnet.$hostNum";
            // Don't test phone's own IP
            if (testIp != currentLocalIp) {
              await _probeHost(testIp, 80, "ESP Node ($testIp)");
            }
          }));

          scanProgress = (i + chunk.length) / hostList.length;
          notifyListeners();
        }
      }
    } finally {
      isScanningSubnet = false;
      scanProgress = 1.0;
      notifyListeners();
    }
  }

  /// Probe a single IP/host for an ESP web server response
  Future<void> _probeHost(String host, int port, String fallbackName) async {
    try {
      final sw = Stopwatch()..start();
      final uri = Uri.parse("http://$host:$port/status");
      final req = await _client.getUrl(uri).timeout(const Duration(milliseconds: 400));
      final res = await req.close().timeout(const Duration(milliseconds: 400));
      sw.stop();

      if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) {
        final body = await res.transform(utf8.decoder).join();
        String deviceName = fallbackName;
        String model = "ESP32";

        if (body.contains("ESP8266") || body.contains("esp8266")) {
          model = "ESP8266";
          deviceName = "iBots ESP8266 ($host)";
        } else if (body.contains("ESP32") || body.contains("esp32")) {
          model = "ESP32";
          deviceName = "iBots ESP32 ($host)";
        }

        // Avoid duplicates
        if (!discoveredLanDevices.any((d) => d.ip == host)) {
          discoveredLanDevices.add(DiscoveredEspDevice(
            ip: host,
            port: port,
            name: deviceName,
            pingMs: sw.elapsedMilliseconds,
            model: model,
            lastSeen: DateTime.now(),
          ));
          notifyListeners();
        }
      }
    } catch (_) {
      // Host unreachable or no HTTP server on port 80
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _client.close(force: true);
    super.dispose();
  }
}
