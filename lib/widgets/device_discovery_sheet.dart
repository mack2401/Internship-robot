import 'package:flutter/material.dart';
import '../core/state/robot_state.dart';
import '../core/database/device_database.dart';
import '../core/wifi/wifi_service.dart';
import 'wifi_connect_dialog.dart';

class DeviceDiscoverySheet extends StatefulWidget {
  final String protocol;
  const DeviceDiscoverySheet({super.key, required this.protocol});

  static Future<void> show(BuildContext context, String protocol) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceDiscoverySheet(protocol: protocol),
    );
  }

  @override
  State<DeviceDiscoverySheet> createState() => _DeviceDiscoverySheetState();
}

class _DeviceDiscoverySheetState extends State<DeviceDiscoverySheet> with SingleTickerProviderStateMixin {
  final RobotState state = RobotState();
  late AnimationController _radarController;
  int _wifiTab = 0; // 0 = Hotspot (SoftAP), 1 = Local Network (Router)
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.100");
  final TextEditingController _portController = TextEditingController(text: "80");

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Start scanning safely after initial frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) state.startScanning();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _ipController.dispose();
    _portController.dispose();
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'arm':
        return Icons.precision_manufacturing;
      case 'cam':
        return Icons.videocam;
      case 'relay':
        return Icons.toggle_on;
      case 'gateway':
        return Icons.router;
      case 'rover':
      default:
        return Icons.smart_toy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanProto = state.activeProtocol;
    final isWifi = cleanProto.toLowerCase().contains("wi-fi") || cleanProto.toLowerCase().contains("wifi");
    final title = isWifi ? "Wi-Fi Networks & APs" : (cleanProto.contains("BLE") ? "BLE 5.2 Device Discovery" : "Bluetooth Devices");
    final target = state.targetDevice ?? state.currentDevice;

    // Filter paired profiles for current protocol + real phone bonded devices
    final List<DeviceProfile> matchingProfiles = List.from(state.pairedProfiles.where((p) {
      if (cleanProto.contains("Classic") || cleanProto.contains("Bluetooth") || cleanProto.contains("BLE")) {
        return p.protocol.contains("Classic") || p.protocol.contains("Bluetooth") || p.protocol.contains("BLE");
      }
      return p.protocol.contains("Wi-Fi") || p.protocol.contains("WiFi");
    }));

    // Merge real phone bonded devices if protocol is Bluetooth/BLE
    if (!isWifi) {
      for (var dev in state.bleService.realBondedDevices) {
        if (!matchingProfiles.any((p) => p.macAddress == dev.macAddress)) {
          matchingProfiles.add(DeviceProfile(
            id: dev.id,
            name: dev.name,
            macAddress: dev.macAddress,
            ipAddress: dev.ipAddress,
            protocol: dev.protocol,
            deviceType: dev.deviceType,
            lastConnected: DateTime.now().subtract(const Duration(minutes: 10)),
          ));
        }
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle notch
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Top Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Icon(
                        isWifi ? Icons.wifi : Icons.bluetooth,
                        color: const Color(0xFF0284C7),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          state.isRadioEnabled ? "Discoverable as mobile phone" : "Radio is turned OFF",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Radio Toggle Switch (like phone settings)
                Switch(
                  value: state.isRadioEnabled,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) => state.toggleRadio(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scan status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (state.isScanning)
                      RotationTransition(
                        turns: _radarController,
                        child: const Icon(Icons.sync, size: 16, color: Color(0xFF0284C7)),
                      )
                    else
                      const Icon(Icons.radar, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      state.isScanning ? "Scanning nearby ${isWifi ? 'networks' : 'devices'}..." : "Scan completed",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: state.isScanning ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: state.isScanning ? null : state.startScanning,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text("Scan Again", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Device Lists
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // WI-FI MODE SELECTOR & CONFIGURATION (Shown when protocol is Wi-Fi)
                if (isWifi) ...[
                  _buildWifiModesCard(),
                  const SizedBox(height: 20),
                ],

                // SECTION 1: PREVIOUSLY CONNECTED DEVICES (SQLite & Drift)
                _buildSectionHeader(
                  title: "PAIRED PROFILES (SQLite + Drift)",
                  count: matchingProfiles.length,
                  badge: "SQLite Saved",
                ),
                const SizedBox(height: 8),
                if (matchingProfiles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      "No saved profiles found in SQLite for this protocol.\nConnect to a nearby device to save its profile.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                else
                  ...matchingProfiles.map((profile) {
                    final isSelectedTarget = target.id == profile.id;
                    final isLiveConnected = state.currentDevice.id == profile.id && state.currentDevice.isConnected;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLiveConnected
                              ? const Color(0xFF10B981)
                              : (isSelectedTarget ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
                          width: (isLiveConnected || isSelectedTarget) ? 1.5 : 1,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isLiveConnected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getDeviceIcon(profile.deviceType),
                            color: isLiveConnected ? const Color(0xFF059669) : const Color(0xFF475569),
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
                            if (isLiveConnected) ...[
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
                            ] else if (isSelectedTarget) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBAE6FD)),
                                ),
                                child: const Text("TARGET", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              "${profile.macAddress} • Saved Profile",
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                            ),
                            Text(
                              "Last sync: ${_formatDateTime(profile.lastConnected)}",
                              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: "Forget Profile",
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                state.forgetDevice(profile.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Removed ${profile.name} from SQLite database")),
                                );
                              },
                            ),
                            GestureDetector(
                              onTap: () {
                                final dev = profile.toRoboticDevice();
                                state.selectTargetDevice(dev);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Target set to: ${profile.name}")),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelectedTarget ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isSelectedTarget ? "Selected" : "Select",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelectedTarget ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          final dev = profile.toRoboticDevice();
                          state.selectTargetDevice(dev);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Target set to: ${profile.name}")),
                          );
                        },
                      ),
                    );
                  }),

                const SizedBox(height: 20),

                // SECTION 2: AVAILABLE DEVICES NEARBY (Discovered)
                _buildSectionHeader(
                  title: "AVAILABLE DEVICES NEARBY",
                  count: state.nearbyDiscoveredDevices.length,
                  badge: "In Range",
                ),
                const SizedBox(height: 8),
                ...state.nearbyDiscoveredDevices.map((dev) {
                  final isSelectedTarget = target.id == dev.id;
                  final isLiveConnected = state.currentDevice.id == dev.id && state.currentDevice.isConnected;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelectedTarget ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                        width: isSelectedTarget ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getDeviceIcon(dev.deviceType),
                              color: const Color(0xFF0284C7),
                              size: 20,
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              dev.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${dev.rssi} dBm",
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        "${dev.protocol} • ${dev.macAddress}",
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLiveConnected
                              ? const Color(0xFFDC2626)
                              : (isSelectedTarget ? const Color(0xFF059669) : const Color(0xFF0284C7)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (isLiveConnected) {
                            state.disconnectDevice();
                            return;
                          }
                          if (isWifi) {
                            final matching = state.wifiService.availableNetworks.firstWhere(
                              (n) => n.ssid.toLowerCase() == dev.name.toLowerCase(),
                              orElse: () => RealWifiNetwork(
                                ssid: dev.name,
                                bssid: dev.macAddress,
                                level: dev.rssi,
                                frequency: 2412,
                                capabilities: "[WPA2-PSK]",
                                isSaved: true,
                              ),
                            );
                            final ok = await WifiConnectDialog.show(context, matching);
                            if (ok && mounted) {
                              Navigator.pop(context);
                            }
                            return;
                          }
                          state.selectTargetDevice(dev);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Selected and paired ${dev.name}!")),
                          );
                        },
                        child: Text(
                          isLiveConnected ? "Disconnect" : (isWifi ? "Connect" : (isSelectedTarget ? "Selected" : "Pair & Select")),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () async {
                        final isDevWifi = isWifi && (dev.protocol.toLowerCase().contains("wi-fi") || dev.protocol.toLowerCase().contains("wifi"));
                        if (isDevWifi) {
                          final matching = state.wifiService.availableNetworks.firstWhere(
                            (n) => n.ssid.toLowerCase() == dev.name.toLowerCase(),
                            orElse: () => RealWifiNetwork(
                              ssid: dev.name,
                              bssid: dev.macAddress,
                              level: dev.rssi,
                              frequency: 2412,
                              capabilities: "[WPA2-PSK]",
                              isSaved: true,
                            ),
                          );
                          final ok = await WifiConnectDialog.show(context, matching);
                          if (ok && mounted) {
                            Navigator.pop(context);
                          }
                          return;
                        }
                        state.selectTargetDevice(dev);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Selected and paired ${dev.name}!")),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Bottom Action Bar: Connect Now or Done
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.currentDevice.isConnected ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      if (state.connectionStatus == ConnectionStatus.connected) {
                        Navigator.pop(context);
                        state.disconnectDevice();
                      } else if (isWifi) {
                        final phoneWifi = await state.wifiService.refreshConnectedWifi();
                        if (phoneWifi != null && (phoneWifi.isEspHotspot || phoneWifi.ssid.toLowerCase().contains("robot"))) {
                          await state.wifiService.bindProcessToWifi();
                          await state.connectWifi(host: "192.168.4.1", mode: WifiMode.softAp, name: phoneWifi.ssid);
                          if (mounted) Navigator.pop(context);
                          return;
                        }
                        final targetSsid = (target.name.contains("ESP") || target.name.contains("Robot")) ? "iBots-Robot" : target.name;
                        final matching = state.wifiService.availableNetworks.firstWhere(
                          (n) => n.ssid.toLowerCase() == targetSsid.toLowerCase() || n.isEspDevice,
                          orElse: () => RealWifiNetwork(
                            ssid: targetSsid,
                            bssid: target.macAddress,
                            level: target.rssi,
                            frequency: 2412,
                            capabilities: "[WPA2-PSK]",
                            isSaved: true,
                          ),
                        );
                        final ok = await WifiConnectDialog.show(context, matching);
                        if (ok && mounted) Navigator.pop(context);
                      } else {
                        Navigator.pop(context);
                        await state.connectToTargetDevice();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.connectionStatus == ConnectionStatus.connected ? Icons.link_off : Icons.link,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.connectionStatus == ConnectionStatus.connected
                              ? "Disconnect Device"
                              : "Connect to ${target.name.split(' ').take(2).join(' ')}",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required int count, required String badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
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
            "$count • $badge",
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
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

  Widget _buildWifiModesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wifi, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ESP32 & ESP8266 Wi-Fi Connectivity",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      "Choose your connection mode below",
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Switcher for Mode 1 vs Mode 2
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wifiTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _wifiTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _wifiTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.router,
                            size: 15,
                            color: _wifiTab == 0 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "1. Local Network",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _wifiTab == 0 ? FontWeight.bold : FontWeight.w600,
                              color: _wifiTab == 0 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wifiTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _wifiTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _wifiTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_tethering,
                            size: 15,
                            color: _wifiTab == 1 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "2. ESP Hotspot",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _wifiTab == 1 ? FontWeight.bold : FontWeight.w600,
                              color: _wifiTab == 1 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Active Mode Content
          if (_wifiTab == 0) _buildLocalNetworkView() else _buildSoftApView(),
        ],
      ),
    );
  }

  Widget _buildLocalNetworkView() {
    final isWifiConnected = state.wifiService.isConnected && state.wifiService.currentMode == WifiMode.localNetwork;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode 1 Description Banner
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
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 6),
                  Text(
                    "Mode 1: Wi-Fi — Local Network",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "The ESP32 and phone connect to the same Wi-Fi router. The app communicates with the ESP32 using its local IP address.",
                style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
              ),
              const SizedBox(height: 8),
              _buildFeatureBullet("Best for local control"),
              _buildFeatureBullet("Control hardware and monitor sensors"),
              _buildFeatureBullet("No cloud server required"),
              _buildFeatureBullet("Internet access is not necessary once local network is set up"),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // IP & Port Configuration
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
                    controller: _ipController,
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
                    controller: _portController,
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
        const SizedBox(height: 12),

        // Subnet Scanner Action
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                ),
                onPressed: state.isScanning
                    ? null
                    : () async {
                        await state.scanSubnet();
                        if (mounted) setState(() {});
                      },
                icon: state.isScanning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)))
                    : const Icon(Icons.radar, size: 16, color: Color(0xFF0284C7)),
                label: Text(
                  state.isScanning ? "Probing Subnet (/24)..." : "Auto-Discover ESP on LAN",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
              ),
            ),
          ],
        ),

        // Discovered LAN Devices List
        if (state.wifiService.discoveredLanDevices.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text("DISCOVERED ESP DEVICES ON LOCAL ROUTER:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
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
                  const Icon(Icons.memory, size: 20, color: Color(0xFF0284C7)),
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
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(50, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _ipController.text = d.ip;
                      _portController.text = d.port.toString();
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

        const SizedBox(height: 12),

        // Connect button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isWifiConnected ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (isWifiConnected) {
                state.disconnectDevice();
              } else {
                final host = _ipController.text.trim();
                final port = int.tryParse(_portController.text.trim()) ?? 80;
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
                  Navigator.pop(context);
                }
              }
            },
            icon: Icon(isWifiConnected ? Icons.link_off : Icons.link, size: 18),
            label: Text(
              isWifiConnected ? "Disconnect from ESP (${state.wifiService.currentHost})" : "Connect to Local ESP IP",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoftApView() {
    final isSoftApConnected = state.wifiService.isConnected && state.wifiService.currentMode == WifiMode.softAp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode 2 Description Banner
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
              const Row(
                children: [
                  Icon(Icons.wifi_tethering, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Text(
                    "Mode 2: ESP32 Hotspot (SoftAP)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "The ESP32 creates its own Wi-Fi network, and the phone connects directly to it.",
                style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
              ),
              const SizedBox(height: 8),
              _buildFeatureBullet("Works without a Wi-Fi router"),
              _buildFeatureBullet("Useful for initial device configuration"),
              _buildFeatureBullet("Direct standalone control anywhere (outdoors/field)"),
              const SizedBox(height: 8),
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
                    Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "The phone may lose internet access while connected to the ESP32 hotspot.",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Default Credentials Info Box
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
                  Text("Default Gateway IP:", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text("192.168.4.1", style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Default SoftAP SSID:", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text("ESP32_iBots_Robot", style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                ],
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Default Password:", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text("12345678", style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Connect Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSoftApConnected ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (isSoftApConnected) {
                state.disconnectDevice();
              } else {
                final phoneWifi = await state.wifiService.refreshConnectedWifi();
                if (phoneWifi != null && (phoneWifi.isEspHotspot || phoneWifi.ssid.toLowerCase().contains("robot"))) {
                  await state.wifiService.bindProcessToWifi();
                  final ok = await state.connectWifi(
                    host: "192.168.4.1",
                    port: 80,
                    mode: WifiMode.softAp,
                    name: phoneWifi.ssid,
                  );
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connected to ESP Robot: ${phoneWifi.ssid}!")));
                    Navigator.pop(context);
                  }
                  return;
                }

                final matching = state.wifiService.availableNetworks.firstWhere(
                  (n) => n.isEspDevice || n.ssid.toLowerCase().contains("robot"),
                  orElse: () => const RealWifiNetwork(
                    ssid: "iBots-Robot",
                    bssid: "",
                    level: -45,
                    frequency: 2412,
                    capabilities: "[WPA2-PSK]",
                    isSaved: true,
                  ),
                );
                final ok = await WifiConnectDialog.show(context, matching);
                if (ok && mounted) {
                  Navigator.pop(context);
                }
              }
            },
            icon: Icon(isSoftApConnected ? Icons.link_off : Icons.wifi_tethering, size: 18),
            label: Text(
              isSoftApConnected ? "Disconnect from Hotspot (192.168.4.1)" : "Connect to ESP32 Hotspot (192.168.4.1)",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }
}
