import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/state/robot_state.dart';
import '../core/models/device_model.dart';
import '../core/wifi/wifi_service.dart';
import '../widgets/wifi_connect_dialog.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> with SingleTickerProviderStateMixin {
  final RobotState state = RobotState();
  late AnimationController _pulseController;
  int _selectedTransportTab = 0; // 0 = Wi-Fi (ESP32 / ESP8266), 1 = Bluetooth (Classic / BLE)
  int _wifiMode = 0; // 0 = Mode 1: Local Network (Router), 1 = Mode 2: ESP Hotspot (SoftAP)
  final TextEditingController _lanIpController = TextEditingController(text: "192.168.1.100");
  final TextEditingController _lanPortController = TextEditingController(text: "80");

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Prompt real permissions and fetch bonded / Wi-Fi devices on initial entry
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      state.bleService.getBondedDevices();
      final hasPerm = await state.wifiService.checkPermissions();
      if (!hasPerm) {
        await state.wifiService.requestPermissions();
      }
      state.wifiService.checkWifiEnabled();
      state.wifiService.refreshConnectedWifi();
      state.wifiService.loadSavedNetworks();
      state.wifiService.scanRealWifiNetworks();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _lanIpController.dispose();
    _lanPortController.dispose();
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleConnect(RoboticDevice item) async {
    // If the user is on the Bluetooth tab, or if the device is a Bluetooth/BLE/HC-05 device, connect via Bluetooth
    final isBluetooth = _selectedTransportTab == 1 ||
        item.protocol.contains("Bluetooth") ||
        item.protocol.contains("Classic") ||
        item.protocol.contains("BLE") ||
        item.protocol.contains("SPP") ||
        item.name.toLowerCase().contains("hc-05") ||
        item.name.toLowerCase().contains("hc-06") ||
        item.name.toLowerCase().contains("bt05");

    if (!isBluetooth) {
      final isWifi = _selectedTransportTab == 0 &&
          (item.protocol.contains("Wi-Fi") ||
              item.protocol.contains("WiFi") ||
              item.name.toLowerCase().contains("esp32") ||
              item.name.toLowerCase().contains("esp8266"));

      if (isWifi) {
        final matching = state.wifiService.availableNetworks.firstWhere(
          (n) => n.ssid.toLowerCase() == item.name.toLowerCase(),
          orElse: () => RealWifiNetwork(
            ssid: item.name,
            bssid: item.macAddress,
            level: item.rssi,
            frequency: 2412,
            capabilities: "[WPA2-PSK]",
            isSaved: true,
          ),
        );
        _showWifiConnectDialog(matching);
        return;
      }
    }

    state.selectTargetDevice(item);
    await state.connectToTargetDevice();
    if (!state.currentDevice.isConnected && mounted) {
      final err = state.bleService.lastError ?? "Could not connect to ${item.name}.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  err,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'audio':
        return Icons.headphones;
      case 'arm':
        return Icons.precision_manufacturing;
      case 'cam':
        return Icons.videocam;
      case 'relay':
        return Icons.toggle_on;
      case 'rover':
        return Icons.smart_toy;
      default:
        return Icons.bluetooth;
    }
  }

  Widget _buildSignalBadge(int rssi) {
    Color color;
    IconData icon;
    if (rssi >= -60) {
      color = const Color(0xFF059669);
      icon = Icons.signal_cellular_alt;
    } else if (rssi >= -80) {
      color = const Color(0xFFD97706);
      icon = Icons.signal_cellular_alt_2_bar;
    } else {
      color = const Color(0xFFDC2626);
      icon = Icons.signal_cellular_alt_1_bar;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            "$rssi dBm",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWifi = _selectedTransportTab == 0;
    final isScanning = isWifi ? state.wifiService.isScanningNetworks : state.isScanning;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isWifi ? "Wi-Fi Networks & Devices" : "Bluetooth Devices",
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Text(
              isWifi ? "Phone Wi-Fi Scanner, Saved Profiles & ESP" : "Real Mobile Bluetooth Scanner & Linker",
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          if (isWifi)
            IconButton(
              tooltip: "Open Phone Wi-Fi Panel",
              icon: const Icon(Icons.tune, color: Color(0xFF475569)),
              onPressed: () => state.wifiService.openWifiSettings(),
            ),
          IconButton(
            tooltip: isWifi ? "Scan Nearby Wi-Fi" : "Scan for Real Devices",
            icon: isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0284C7)),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF0284C7)),
            onPressed: isScanning
                ? null
                : () => isWifi ? state.wifiService.scanRealWifiNetworks() : state.startScanning(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher: Wi-Fi vs Bluetooth
            _buildTransportSelector(),

            // Transport Content
            Expanded(
              child: isWifi ? _buildWifiTabBody() : _buildBluetoothTabBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                setState(() => _selectedTransportTab = 0);
                final hasPerm = await state.wifiService.checkPermissions();
                if (!hasPerm) {
                  await state.wifiService.requestPermissions();
                }
                state.wifiService.checkWifiEnabled();
                state.wifiService.refreshConnectedWifi();
                state.wifiService.loadSavedNetworks();
                state.wifiService.scanRealWifiNetworks();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTransportTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTransportTab == 0
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi,
                      size: 16,
                      color: _selectedTransportTab == 0 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Wi-Fi (ESP32 / ESP8266)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedTransportTab == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedTransportTab == 0 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTransportTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTransportTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTransportTab == 1
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bluetooth,
                      size: 16,
                      color: _selectedTransportTab == 1 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Bluetooth (Classic/BLE)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedTransportTab == 1 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedTransportTab == 1 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTabBody() {
    final isBtOff = state.bleService.adapterState == BluetoothAdapterState.off;
    final hasConnected = state.currentDevice.isConnected && !state.currentDevice.protocol.contains("Wi-Fi");

    return RefreshIndicator(
      onRefresh: () => state.startScanning(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Adapter / Permission Status Banner
            if (isBtOff)
              _buildBluetoothOffBanner()
            else if (!state.bleService.isPermissionGranted)
              _buildPermissionBanner()
            else if (!state.bleService.isLocationEnabled)
              _buildLocationOffBanner(),

            if (state.isScanning) _buildScanningIndicatorBanner(),

            const SizedBox(height: 12),

            // 2. Currently Connected Device (if connected)
            if (hasConnected) ...[
              _buildConnectedSection(),
              const SizedBox(height: 24),
            ],

            // Discovery Guide & Tips Card
            _buildDiscoveryTipsCard(),
            const SizedBox(height: 20),

            // 3. Paired / Saved Devices from Mobile Phone
            _buildPairedDevicesSection(),
            const SizedBox(height: 24),

            // 4. Available Real-World Discovered Devices
            _buildAvailableDiscoveredSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiTabBody() {
    final ws = state.wifiService;
    final isWifiOff = !ws.isWifiHardwareEnabled;
    final isPermMissing = !ws.isPermissionGranted;

    return RefreshIndicator(
      onRefresh: () => ws.scanRealWifiNetworks(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Wi-Fi Hardware Switched Off Banner
            if (isWifiOff)
              _buildWifiOffBanner()
            else if (isPermMissing)
              _buildWifiPermissionBanner()
            else
              _buildWifiPermissionStatusChip(),

            // 2. Real Wi-Fi Scanning Banner
            if (ws.isScanningNetworks) _buildWifiScanningBanner(),

            const SizedBox(height: 6),

            // 3. Current Connected Network Card (Like Phone's Wi-Fi Settings)
            if (ws.currentPhoneWifi != null || ws.isConnected) ...[
              _buildPhoneConnectedWifiCard(),
              const SizedBox(height: 18),
            ],

            // 4. Already Saved Devices & Networks (from SQLite Database)
            _buildSavedWifiNetworksSection(),
            const SizedBox(height: 20),

            // 5. Available Networks Nearby (Discovered Over-The-Air)
            _buildAvailableWifiNetworksSection(),
            const SizedBox(height: 22),

            // 6. Direct Wi-Fi Mode Configuration (Mode 1: Router vs Mode 2: SoftAP)
            _buildWifiModeSwitcher(),
            const SizedBox(height: 14),
            if (_wifiMode == 0) _buildLocalNetworkCard() else _buildSoftApCard(),
            const SizedBox(height: 18),

            // 7. System Wi-Fi settings shortcut button & Arduino Firmware Helper
            _buildWifiSystemSettingsButton(),
            const SizedBox(height: 14),
            _buildWifiFirmwareInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiPermissionStatusChip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Wi-Fi & Location Permissions: Active",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ),
          InkWell(
            onTap: () => state.wifiService.openAppSettings(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                "App Info",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiOffBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFD97706), size: 26),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Phone Wi-Fi is Switched Off",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
                SizedBox(height: 2),
                Text(
                  "Turn on Wi-Fi to scan for nearby networks and connect to ESP32 / ESP8266 robots.",
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => state.wifiService.openWifiSettings(),
            child: const Text("Turn On", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiPermissionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Color(0xFF0284C7), size: 26),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Wi-Fi & Location Permissions Needed",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF075985)),
                ),
                SizedBox(height: 2),
                Text(
                  "Android requires Location & Nearby Wi-Fi permissions to scan and show real visible networks.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => state.wifiService.requestPermissions(),
                child: const Text("Allow", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => state.wifiService.openAppSettings(),
                child: const Text(
                  "Settings",
                  style: TextStyle(fontSize: 10, color: Color(0xFF0284C7), decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWifiConnectDialog(RealWifiNetwork net) {
    WifiConnectDialog.show(context, net);
  }

  Widget _buildWifiScanningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Scanning for visible Wi-Fi access points & ESP devices...",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneConnectedWifiCard() {
    final ws = state.wifiService;
    final info = ws.currentPhoneWifi;
    final isEsp = info?.isEspHotspot ?? false;
    final ssid = info?.ssid ?? (ws.currentDeviceName ?? "Connected Wi-Fi");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            "Currently Connected Wi-Fi",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C059669),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEsp ? "★ CONNECTED TO ESP ROBOT AP" : "CONNECTED TO LOCAL WI-FI",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  if (info != null && info.linkSpeed > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${info.linkSpeed} Mbps • ${info.rssi} dBm",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.wifi,
                      size: 26,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ssid,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          info != null
                              ? "Phone IP: ${info.ip} • Gateway: ${info.gateway}"
                              : "http://${ws.currentHost}:${ws.currentPort}",
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      state.disconnectDevice();
                      state.wifiService.openWifiSettings();
                    },
                    child: const Text("Disconnect", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (ws.isConnected) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTelemetryItem(Icons.battery_charging_full, "${state.batteryVoltage.toStringAsFixed(1)}V", "Battery", const Color(0xFF10B981)),
                    _buildTelemetryItem(Icons.radar, "${state.proximityDistance.toInt()} cm", "Sonar", const Color(0xFF0284C7)),
                    _buildTelemetryItem(Icons.thermostat, "${state.coreTemperature.toInt()}°C", "Temp", const Color(0xFFF59E0B)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedWifiNetworksSection() {
    final ws = state.wifiService;
    final saved = ws.savedWifiProfiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "SAVED WI-FI DEVICES & NETWORKS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Color(0xFF475569),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${saved.length} • Saved",
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (saved.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "No saved Wi-Fi networks yet. Connect to a nearby ESP or Wi-Fi network below to save it.",
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          )
        else
          ...saved.map((profile) {
            final isLive = ws.currentPhoneWifi?.ssid.toLowerCase() == profile.name.toLowerCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  width: isLive ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isLive ? const Color(0xFFECFDF5) : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.wifi,
                    color: isLive ? const Color(0xFF059669) : const Color(0xFF0284C7),
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text("CONNECTED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  "${profile.protocol} • Saved Profile • ${_formatDateTime(profile.lastConnected)}",
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
                onTap: () {
                  final matching = ws.availableNetworks.firstWhere(
                    (n) => n.ssid.toLowerCase() == profile.name.toLowerCase(),
                    orElse: () => RealWifiNetwork(
                      ssid: profile.name,
                      bssid: profile.macAddress,
                      level: profile.rssi,
                      frequency: 2400,
                      capabilities: "[WPA2-PSK]",
                      isSaved: true,
                    ),
                  );
                  _showWifiConnectDialog(matching);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Forget Network",
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        ws.forgetNetwork(profile.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Removed ${profile.name} from saved profiles")),
                        );
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLive ? const Color(0xFF059669) : const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final matching = ws.availableNetworks.firstWhere(
                          (n) => n.ssid.toLowerCase() == profile.name.toLowerCase(),
                          orElse: () => RealWifiNetwork(
                            ssid: profile.name,
                            bssid: profile.macAddress,
                            level: profile.rssi,
                            frequency: 2400,
                            capabilities: "[WPA2-PSK]",
                            isSaved: true,
                          ),
                        );
                        _showWifiConnectDialog(matching);
                      },
                      child: Text(
                        isLive ? "Active" : "Connect",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAvailableWifiNetworksSection() {
    final ws = state.wifiService;
    final networks = ws.availableNetworks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "AVAILABLE NETWORKS NEARBY",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Color(0xFF475569),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${networks.length} • Visible",
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (networks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_find, size: 20, color: Color(0xFF0284C7)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "No Wi-Fi networks found. Tap 'Scan Nearby Wi-Fi' at top or check that phone Location/GPS is enabled.",
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ),
                TextButton(
                  onPressed: () => ws.scanRealWifiNetworks(),
                  child: const Text("Scan", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        else
          ...networks.map((net) {
            final isConnected = net.isConnected || (ws.currentPhoneWifi?.ssid == net.ssid);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isConnected
                      ? const Color(0xFF10B981)
                      : (net.isEspDevice ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
                  width: (isConnected || net.isEspDevice) ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: _buildWifiSignalIcon(net),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        net.ssid,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (net.isEspDevice) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text("★ ESP ROBOT", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                      ),
                    ] else if (net.isSaved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("SAVED", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  "${net.securityLabel} • ${net.is5Ghz ? '5 GHz' : '2.4 GHz'} • ${net.level} dBm",
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected
                        ? const Color(0xFF059669)
                        : (net.isEspDevice ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9)),
                    foregroundColor: (isConnected || net.isEspDevice) ? Colors.white : const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(64, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _showWifiConnectDialog(net),
                  child: Text(
                    isConnected ? "Connected" : (net.isEspDevice ? "Connect" : "Join"),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () => _showWifiConnectDialog(net),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildWifiSignalIcon(RealWifiNetwork net) {
    IconData icon;
    Color color;

    if (net.signalBars == 4) {
      icon = Icons.wifi;
      color = const Color(0xFF059669);
    } else if (net.signalBars == 3) {
      icon = Icons.wifi_2_bar;
      color = const Color(0xFF0284C7);
    } else {
      icon = Icons.wifi_1_bar;
      color = const Color(0xFFD97706);
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        if (!net.isOpen)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFF475569),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, size: 8, color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildWifiSystemSettingsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        onPressed: () => state.wifiService.openWifiSettings(),
        icon: const Icon(Icons.settings, size: 16, color: Color(0xFF475569)),
        label: const Text(
          "Open Phone's Native Wi-Fi Settings Panel",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else {
      return "${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }

  Widget _buildTelemetryItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildWifiModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _wifiMode = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _wifiMode == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _wifiMode == 0
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.router, size: 15, color: _wifiMode == 0 ? const Color(0xFF059669) : const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      "1. Local Network",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _wifiMode == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _wifiMode == 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _wifiMode = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _wifiMode == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _wifiMode == 1
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_tethering, size: 15, color: _wifiMode == 1 ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      "2. ESP Hotspot (SoftAP)",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _wifiMode == 1 ? FontWeight.bold : FontWeight.w600,
                        color: _wifiMode == 1 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalNetworkCard() {
    final isWifiConnected = state.wifiService.isConnected && state.wifiService.currentMode == WifiMode.localNetwork;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.router, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mode 1: Wi-Fi — Local Network",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      "Connect through your home / office Wi-Fi router",
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Overview description banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "The ESP32 and phone connect to the same Wi-Fi router. The app communicates with the ESP32 using its local IP address.",
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), height: 1.35),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Best for local control",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
                const SizedBox(height: 4),
                _buildCheckBullet("Control hardware and monitor sensors."),
                _buildCheckBullet("No cloud server required."),
                _buildCheckBullet("Internet access is not necessary once the local network is set up."),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick IP Presets
          const Text("QUICK IP PRESETS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildIpPresetChip("192.168.1.100"),
              _buildIpPresetChip("192.168.0.100"),
              _buildIpPresetChip("192.168.43.100"),
              _buildIpPresetChip("esp32.local"),
              _buildIpPresetChip("esp8266.local"),
            ],
          ),
          const SizedBox(height: 14),

          // IP and Port Inputs
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ESP IP Address / Host", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _lanIpController,
                      decoration: InputDecoration(
                        hintText: "192.168.1.100 or esp32.local",
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Port", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _lanPortController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "80",
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subnet Scanner Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFF059669)),
            ),
            onPressed: state.isScanning
                ? null
                : () async {
                    await state.scanSubnet();
                    if (mounted) setState(() {});
                  },
            icon: state.isScanning
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)))
                : const Icon(Icons.radar, size: 16, color: Color(0xFF059669)),
            label: Text(
              state.isScanning ? "Scanning Local Subnet (/24)..." : "Auto-Discover ESP on Router Subnet",
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
            ),
          ),

          // Discovered LAN Devices List
          if (state.wifiService.discoveredLanDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("DISCOVERED ESP NODES ON ROUTER:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            ...state.wifiService.discoveredLanDevices.map((d) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory, size: 20, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text("${d.ip}:${d.port} • Ping: ${d.pingMs}ms", style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(50, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _lanIpController.text = d.ip;
                        _lanPortController.text = d.port.toString();
                        state.connectWifi(
                          host: d.ip,
                          port: d.port,
                          mode: WifiMode.localNetwork,
                          name: d.name,
                        );
                      },
                      child: const Text("Connect", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 14),

          // Primary Connect Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWifiConnected ? const Color(0xFFDC2626) : const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
              onPressed: () async {
                if (isWifiConnected) {
                  state.disconnectDevice();
                } else {
                  final host = _lanIpController.text.trim();
                  final port = int.tryParse(_lanPortController.text.trim()) ?? 80;
                  if (host.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter ESP IP Address")));
                    return;
                  }
                  final ok = await state.connectWifi(
                    host: host,
                    port: port,
                    mode: WifiMode.localNetwork,
                    name: "ESP32 (LAN: $host)",
                  );
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connected to ESP32 at $host!")));
                  }
                }
              },
              icon: Icon(isWifiConnected ? Icons.link_off : Icons.link, size: 18),
              label: Text(
                isWifiConnected ? "Disconnect from ESP (${state.wifiService.currentHost})" : "Connect to Local ESP IP",
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftApCard() {
    final isSoftApConnected = state.wifiService.isConnected && state.wifiService.currentMode == WifiMode.softAp;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wifi_tethering, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mode 2: ESP32 Hotspot (SoftAP)",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      "Direct point-to-point Wi-Fi connection without a router",
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Overview description banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "The ESP32 creates its own Wi-Fi network, and the phone connects directly to it.",
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), height: 1.35),
                ),
                const SizedBox(height: 8),
                _buildCheckBullet("Works without a Wi-Fi router."),
                _buildCheckBullet("Useful for initial device configuration."),
                _buildCheckBullet("Direct standalone control outdoors or in the field."),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "The phone may lose internet access while connected to the ESP32 hotspot.",
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hotspot Credentials Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Gateway IP Address:", style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    Text("192.168.4.1", style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Default SoftAP SSID:", style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    Text("ESP32_iBots_Robot", style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Default Password:", style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    Text("12345678", style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 Steps
          const Text("QUICK CONNECTION STEPS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          _buildStepRow("1", "Turn ON your ESP32 robot board."),
          _buildStepRow("2", "In phone Wi-Fi settings, connect to 'ESP32_iBots_Robot' (pass: 12345678)."),
          _buildStepRow("3", "Tap the button below to link with 192.168.4.1."),
          const SizedBox(height: 16),

          // Connect Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSoftApConnected ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
              onPressed: () async {
                if (isSoftApConnected) {
                  state.disconnectDevice();
                } else {
                  final phoneWifi = state.wifiService.currentPhoneWifi;
                  final isPhoneOnEsp = phoneWifi?.isEspHotspot ?? false;

                  if (!isPhoneOnEsp) {
                    final espNet = state.wifiService.availableNetworks.firstWhere(
                      (n) => n.isEspDevice || n.ssid.toLowerCase().contains("ibots") || n.ssid.toLowerCase().contains("robot"),
                      orElse: () => const RealWifiNetwork(
                        ssid: "iBots-Robot",
                        bssid: "26:d7:eb:fd:bc:10",
                        level: -38,
                        frequency: 2412,
                        capabilities: "[WPA2-PSK]",
                      ),
                    );
                    _showWifiConnectDialog(espNet);
                    return;
                  }

                  final ok = await state.connectWifi(
                    host: "192.168.4.1",
                    port: 80,
                    mode: WifiMode.softAp,
                    name: phoneWifi?.ssid ?? "ESP32 Hotspot",
                  );
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connected to ESP32 Hotspot!")));
                  }
                }
              },
              icon: Icon(isSoftApConnected ? Icons.link_off : Icons.wifi_tethering, size: 18),
              label: Text(
                isSoftApConnected ? "Disconnect from Hotspot (192.168.4.1)" : "Connect to ESP32 Hotspot (192.168.4.1)",
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpPresetChip(String ip) {
    return ActionChip(
      label: Text(ip, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      onPressed: () {
        setState(() {
          _lanIpController.text = ip;
        });
      },
    );
  }

  Widget _buildCheckBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("✓ ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _buildStepRow(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF0284C7),
              shape: BoxShape.circle,
            ),
            child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _buildWifiFirmwareInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.code, size: 16, color: Color(0xFF0284C7)),
              SizedBox(width: 6),
              Text(
                "ESP32 Wi-Fi Command Protocol",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "The app communicates via HTTP requests with minimal latency:",
            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• Motion & Relays: GET http://<IP>/cmd?val=F", style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF0284C7))),
                Text("• Telemetry Polling: GET http://<IP>/status", style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF059669))),
                Text("  Returns: {\"battery\":8.4, \"distance\":45, \"temp\":38}", style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothOffBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_disabled, color: Color(0xFFD97706), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Bluetooth is Turned Off",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
                SizedBox(height: 2),
                Text(
                  "Turn on your phone's Bluetooth to discover and connect to real-world devices.",
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => state.bleService.ensureBluetoothOn(),
            child: const Text("Turn On", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Color(0xFF0284C7), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Bluetooth Permission Required",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF075985)),
                ),
                SizedBox(height: 2),
                Text(
                  "Allow nearby device and location permissions to scan real Bluetooth hardware.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => state.bleService.requestPermissions(),
            child: const Text("Allow", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationOffBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Color(0xFFD97706), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Phone Location (GPS) is Switched Off",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
                SizedBox(height: 2),
                Text(
                  "Android strictly requires Location/GPS to be enabled in your top notification panel to scan for nearby un-paired Bluetooth devices.",
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => state.bleService.checkLocationService(),
            child: const Text("Recheck", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF0284C7)),
              SizedBox(width: 6),
              Text(
                "How to make devices visible:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "• Scanning for another phone/laptop? Open Settings → Bluetooth on that device. Android & iPhone only broadcast their Bluetooth signal while their Bluetooth settings screen is open.",
            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          const Text(
            "• Scanning for Arduino / HC-05? Ensure its red LED is blinking rapidly (ready to pair), or pair it once in phone Bluetooth settings with PIN 1234.",
            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          const Text(
            "• Ensure Location (GPS) is turned ON in your phone's notification bar.",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicatorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Scanning for nearby real-world Bluetooth devices...",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
            ),
          ),
          TextButton(
            onPressed: () => state.bleService.stopScan(),
            child: const Text("Stop", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedSection() {
    final dev = state.currentDevice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            "Currently Connected Device",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Icon(_getIconForType(dev.deviceType), color: const Color(0xFF059669), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${dev.protocol} • ${dev.macAddress}",
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFDC2626),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => state.disconnectDevice(),
                    child: const Text("Disconnect", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        const Text(
                          "Active Link Live",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                    _buildSignalBadge(dev.rssi),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPairedDevicesSection() {
    // Combine real phone bonded devices with saved SQLite profiles
    final realBonded = state.bleService.realBondedDevices;
    final sqliteProfiles = state.pairedProfiles;

    final Map<String, RoboticDevice> combined = {};
    for (var b in realBonded) {
      combined[b.macAddress] = b;
    }
    for (var p in sqliteProfiles) {
      if (!combined.containsKey(p.macAddress)) {
        combined[p.macAddress] = p.toRoboticDevice();
      }
    }
    final pairedList = combined.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Paired & Saved Devices",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF0284C7)),
                    tooltip: "Reload Paired Devices",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      await state.bleService.getBondedDevices();
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${pairedList.length} Saved",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (pairedList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                "No paired Bluetooth devices detected on your phone yet.\nTurn on a Bluetooth device or pair one in your phone's Settings.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          Column(
            children: pairedList.map((item) {
              final isLiveConnected = state.currentDevice.id == item.id && state.currentDevice.isConnected;
              final isConnecting = state.connectionStatus == ConnectionStatus.connecting && state.targetDevice?.id == item.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLiveConnected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    width: isLiveConnected ? 1.5 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isLiveConnected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getIconForType(item.deviceType), size: 20, color: isLiveConnected ? const Color(0xFF059669) : const Color(0xFF475569)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isLiveConnected) ...[
                                      const SizedBox(width: 6),
                                      const Text("• CONNECTED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.macAddress,
                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLiveConnected
                            ? const Color(0xFFFEF2F2)
                            : (isConnecting ? const Color(0xFFE0F2FE) : const Color(0xFF0284C7)),
                        foregroundColor: isLiveConnected
                            ? const Color(0xFFDC2626)
                            : (isConnecting ? const Color(0xFF0284C7) : Colors.white),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isConnecting
                          ? null
                          : () {
                              if (isLiveConnected) {
                                state.disconnectDevice();
                              } else {
                                _handleConnect(item);
                              }
                            },
                      child: isConnecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                            )
                          : Text(
                              isLiveConnected ? "Disconnect" : "Connect",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAvailableDiscoveredSection() {
    final discovered = state.nearbyDiscoveredDevices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Available Nearby Devices",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  if (state.isScanning)
                    const Text(
                      "Scanning...  ",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0284C7)),
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state.isScanning ? null : () => state.startScanning(),
                    icon: const Icon(Icons.search, size: 14),
                    label: const Text("Scan", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (discovered.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    state.isScanning ? Icons.radar : Icons.bluetooth_searching,
                    size: 36,
                    color: state.isScanning ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.isScanning
                        ? "Scanning for Bluetooth & BLE devices nearby..."
                        : "No nearby Bluetooth devices discovered yet.\nTap 'Scan' to search for active Bluetooth devices in your room.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: discovered.map((dev) {
              final isConnected = state.currentDevice.id == dev.id && state.currentDevice.isConnected;
              final isConnecting = state.connectionStatus == ConnectionStatus.connecting && state.targetDevice?.id == dev.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isConnected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getIconForType(dev.deviceType), size: 20, color: const Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        dev.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildSignalBadge(dev.rssi),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dev.macAddress,
                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected
                            ? const Color(0xFFFEF2F2)
                            : (isConnecting ? const Color(0xFFE0F2FE) : const Color(0xFF0284C7)),
                        foregroundColor: isConnected
                            ? const Color(0xFFDC2626)
                            : (isConnecting ? const Color(0xFF0284C7) : Colors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isConnecting
                          ? null
                          : () {
                              if (isConnected) {
                                state.disconnectDevice();
                              } else {
                                _handleConnect(dev);
                              }
                            },
                      child: isConnecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                            )
                          : Text(
                              isConnected ? "Disconnect" : "Connect",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
