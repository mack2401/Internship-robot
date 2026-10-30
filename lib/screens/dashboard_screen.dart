import 'package:flutter/material.dart';
import '../core/state/robot_state.dart';
import '../widgets/device_discovery_sheet.dart';
import '../widgets/wifi_connect_dialog.dart';
import '../core/wifi/wifi_service.dart';
import 'car_controller_screen.dart';
import 'gamepad_screen.dart';
import 'led_lamp_screen.dart';
import 'switch_panel_screen.dart';
import 'terminal_screen.dart';
import 'voice_control_screen.dart';
import 'keypad_screen.dart';
import 'telemetry_screen.dart';
import 'esp32_cam_screen.dart';
import 'robotic_arm_screen.dart';
import 'gyro_control_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RobotState state = RobotState();
  String? _toastMessage;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    setState(() {
      _toastMessage = message;
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand Header
                  _buildBrandHeader(),
                  const SizedBox(height: 12),
                  // Device Connection Card
                  _buildDeviceConnectionCard(),
                  const SizedBox(height: 24),
                  // Control Center Header
                  _buildSectionHeader(),
                  const SizedBox(height: 12),
                  // 11 Feature Tools Grid
                  _buildToolsGrid(),
                ],
              ),
            ),
          ),
          // Floating Quick Toast matching Stitch HTML
          if (_toastMessage != null)
            Positioned(
              bottom: 84,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withAlpha(240),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _toastMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Logo image with fallback
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    "https://lh3.googleusercontent.com/aida-public/AB6AXuDFs2LbIXZIrz5J2at025gNIxQRRMEJ7U2h82bJQL1Ad1pz1Xz0cKMzfb13ER6AcXZvqnjKp3SpOh9QF4yi4VF6qi0DhSW-opHyNv1wYtgVHl65XC1H6ZPqe-nvajhzlYzFku2JlRK3yWCyP2cBbcvWs7gWo5lZjs4bftrceSQMbp4IEt1ctNkzbMwsX0GP3oxUxJ3BXSiFRR--o68jnRj3wsGP-8BrxK9ioA6cP4x-WebiUbaHKeKLs-YYwzp4cpOfcqs",
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x330284C7),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.smart_toy, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    "iBots Remote Controller",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B), size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handlePrimaryConnect() async {
    final dev = state.currentDevice;
    final target = state.targetDevice ?? dev;
    final isWifi = state.activeProtocol.contains("Wi-Fi") ||
        state.activeProtocol.contains("WiFi") ||
        target.protocol.contains("Wi-Fi") ||
        target.protocol.contains("WiFi") ||
        target.name.toLowerCase().contains("esp") ||
        target.name.toLowerCase().contains("robot");

    if (isWifi) {
      // 1. Check if phone is already connected to an ESP Wi-Fi AP
      final phoneWifi = await state.wifiService.refreshConnectedWifi();
      if (phoneWifi != null &&
          (phoneWifi.isEspHotspot ||
              phoneWifi.ssid.toLowerCase().contains("robot") ||
              phoneWifi.ssid.toLowerCase().contains("esp") ||
              phoneWifi.ssid.toLowerCase().contains("ibots") ||
              phoneWifi.ip.startsWith("192.168.4."))) {
        _showToast("Linking to ${phoneWifi.ssid} (192.168.4.1)...");
        await state.wifiService.bindProcessToWifi();
        final ok = await state.connectWifi(host: "192.168.4.1", mode: WifiMode.softAp, name: phoneWifi.ssid);
        if (ok) {
          _showToast("Connected to ${phoneWifi.ssid} (192.168.4.1)!");
        } else {
          _showToast("Could not reach 192.168.4.1. Check ESP power.");
        }
        return;
      }

      // 2. Otherwise prompt user with Wi-Fi Password Dialog
      final targetSsid = (target.name.contains("ESP") || target.name.contains("Robot") || target.name.contains("Mecanum"))
          ? "iBots-Robot"
          : target.name;
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

      final ok = await WifiConnectDialog.show(context, matching, onSuccess: () {
        _showToast("Connected to ${matching.ssid}!");
      });
      if (ok) {
        _showToast("Connected to ${matching.ssid}!");
      }
      return;
    }

    // Bluetooth / BLE
    _showToast("Connecting to ${target.name}...");
    await state.connectToTargetDevice();
    if (state.isConnected) {
      _showToast("Connected to ${target.name}!");
    } else {
      _showToast("Could not connect to ${target.name}");
    }
  }

  Widget _buildDeviceConnectionCard() {
    final dev = state.currentDevice;
    final target = state.targetDevice ?? dev;
    final isConnected = state.connectionStatus == ConnectionStatus.connected;
    final isConnecting = state.connectionStatus == ConnectionStatus.connecting;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () => DeviceDiscoverySheet.show(context, state.activeProtocol),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.memory, color: Color(0xFF0284C7), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          "Your device",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Connection Status Badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? const Color(0xFFECFDF5)
                        : (isConnecting ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(20),
                    border: isConnected
                        ? Border.all(color: const Color(0xFFA7F3D0))
                        : (isConnecting ? Border.all(color: const Color(0xFFFDE68A)) : null),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? const Color(0xFF10B981)
                              : (isConnecting ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          isConnected
                              ? "Connected (${target.name.contains('ESP32') ? 'ESP32-S3' : target.name.split(' ').first})"
                              : (isConnecting ? "Connecting..." : "Disconnected"),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isConnected
                                ? const Color(0xFF059669)
                                : (isConnecting ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Protocol Switcher Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                _buildProtocolTab("Bluetooth", "(Classic)", Icons.bluetooth, "Bluetooth (Classic)"),
                const SizedBox(width: 6),
                _buildProtocolTab("BLE", "Low energy", Icons.bluetooth_searching, "BLE 5.2"),
                const SizedBox(width: 6),
                _buildProtocolTab("Wi-Fi", "Wireless", Icons.wifi, "Wi-Fi AP"),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Target Module Row
          GestureDetector(
            onTap: () => DeviceDiscoverySheet.show(context, state.activeProtocol),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: "Target: ",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                        children: [
                          TextSpan(
                            text: "${target.name} (${state.activeProtocol})",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isConnected)
                    Row(
                      children: [
                        const Icon(Icons.signal_cellular_alt, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          "${target.rssi} dBm",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF059669)),
                        ),
                      ],
                    )
                  else
                    const Row(
                      children: [
                        Icon(Icons.tune, size: 12, color: Color(0xFF0284C7)),
                        SizedBox(width: 3),
                        Text(
                          "Change",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Gradient Primary Action Button
          GestureDetector(
            onTap: () async {
              if (isConnecting) return;
              if (isConnected) {
                state.disconnectDevice();
                _showToast("Device disconnected");
              } else {
                await _handlePrimaryConnect();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isConnected
                      ? const [Color(0xFFF43F5E), Color(0xFFE11D48)]
                      : (isConnecting
                          ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                          : const [Color(0xFF0EA5E9), Color(0xFF0284C7)]),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isConnected ? const Color(0xFFE11D48) : const Color(0xFF0284C7)).withAlpha(80),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isConnecting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    Icon(
                      isConnected ? Icons.power_settings_new : Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected
                        ? "Disconnect Device"
                        : (isConnecting ? "Connecting to ${state.activeProtocol}..." : "+ Connect Device +"),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolTab(String title, String subtitle, IconData icon, String protocolKey) {
    final isSelected = state.activeProtocol == protocolKey ||
        (protocolKey == "Bluetooth (Classic)" && state.activeProtocol.contains("Classic"));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          state.setProtocol(protocolKey);
          _showToast("Protocol switched to $protocolKey");
          // Open phone-like device discovery bottom sheet
          DeviceDiscoverySheet.show(context, protocolKey);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFFBAE6FD), width: 1)
                : null,
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Your control center",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0).withAlpha(160),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "11 tools",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid() {
    final tools = [
      _ToolCardData(
        title: "Car Controller",
        gradientStart: const Color(0xFFF0F9FF),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF0284C7),
        visualWidget: _buildCarVisual(),
        screen: const CarControllerScreen(),
      ),
      _ToolCardData(
        title: "Virtual Gamepad",
        gradientStart: const Color(0xFFEEF2FF),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF4F46E5),
        visualWidget: _buildGamepadVisual(),
        screen: const GamepadScreen(),
      ),
      _ToolCardData(
        title: "LED & RGB Control",
        gradientStart: const Color(0xFFFFFBEB),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFFD97706),
        visualWidget: _buildLedVisual(),
        screen: const LedLampScreen(),
      ),
      _ToolCardData(
        title: "Switch Panel",
        gradientStart: const Color(0xFFECFDF5),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF059669),
        visualWidget: _buildSwitchVisual(),
        screen: const SwitchPanelScreen(),
      ),
      _ToolCardData(
        title: "Text Terminal",
        gradientStart: const Color(0xFFF0F9FF),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF0284C7),
        visualWidget: _buildTerminalVisual(),
        screen: const TerminalScreen(),
      ),
      _ToolCardData(
        title: "Voice Control",
        gradientStart: const Color(0xFFFAF5FF),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF9333EA),
        visualWidget: _buildVoiceVisual(),
        screen: const VoiceControlScreen(),
      ),
      _ToolCardData(
        title: "Virtual Keypad",
        gradientStart: const Color(0xFFF0FDFA),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF0D9488),
        visualWidget: _buildKeypadVisual(),
        screen: const KeypadScreen(),
      ),
      _ToolCardData(
        title: "Telemetry",
        gradientStart: const Color(0xFFFDF2F8),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFFDB2777),
        visualWidget: _buildTelemetryVisual(),
        screen: const TelemetryScreen(),
      ),
      _ToolCardData(
        title: "ESP32 Cam",
        gradientStart: const Color(0xFFF0F9FF),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF0284C7),
        visualWidget: _buildCamVisual(),
        screen: const Esp32CamScreen(),
      ),
      _ToolCardData(
        title: "Robotic Arm",
        gradientStart: const Color(0xFFF0F9FF),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF0284C7),
        visualWidget: _buildArmVisual(),
        screen: const RoboticArmScreen(),
      ),
      _ToolCardData(
        title: "Gyro Control",
        gradientStart: const Color(0xFFF0F9FF),
        gradientEnd: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF0284C7),
        visualWidget: _buildGyroVisual(),
        screen: const GyroControlScreen(),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final t = tools[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => t.screen),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 16,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visual Box Mockup exactly matching Stitch HTML
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [t.gradientStart, t.gradientEnd],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: t.visualWidget,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Stitch Visual Box Renderers ---

  Widget _buildCarVisual() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: const Border(bottom: BorderSide(color: Color(0xFF0284C7), width: 3)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Wheels left/right
              Positioned(
                left: -4,
                child: Container(width: 6, height: 22, decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4))),
              ),
              Positioned(
                right: -4,
                child: Container(width: 6, height: 22, decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 5, color: Color(0xFF22D3EE)),
            SizedBox(width: 14),
            Icon(Icons.circle, size: 5, color: Color(0xFF22D3EE)),
          ],
        ),
      ],
    );
  }

  Widget _buildGamepadVisual() {
    return Container(
      width: 64,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: const Border(bottom: BorderSide(color: Color(0xFF818CF8), width: 2.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(color: Color(0xFF22D3EE), shape: BoxShape.circle),
          ),
          const Row(
            children: [
              Icon(Icons.circle, size: 4, color: Color(0xFF64748B)),
              SizedBox(width: 3),
              Icon(Icons.circle, size: 4, color: Color(0xFF64748B)),
            ],
          ),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(color: Color(0xFFF43F5E), shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildLedVisual() {
    return Container(
      width: 66,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: const Border(bottom: BorderSide(color: Color(0xFF10B981), width: 2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LedBulb(Color(0xFFEC4899)),
          _LedBulb(Color(0xFF22D3EE)),
          _LedBulb(Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildSwitchVisual() {
    return Container(
      width: 64,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: const Border(bottom: BorderSide(color: Color(0xFF22D3EE), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 3, height: 10, decoration: BoxDecoration(color: const Color(0xFF22D3EE), borderRadius: BorderRadius.circular(2))),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF334155), shape: BoxShape.circle)),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF334155), shape: BoxShape.circle)),
              Container(width: 3, height: 10, decoration: BoxDecoration(color: const Color(0xFF64748B), borderRadius: BorderRadius.circular(2))),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 3, height: 10, decoration: BoxDecoration(color: const Color(0xFF22D3EE), borderRadius: BorderRadius.circular(2))),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF334155), shape: BoxShape.circle)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalVisual() {
    return Container(
      width: 68,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 5, color: Color(0xFFEF4444)),
              SizedBox(width: 3),
              Icon(Icons.circle, size: 5, color: Color(0xFFF59E0B)),
              SizedBox(width: 3),
              Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
            ],
          ),
          Text(
            "> AT+OK",
            style: TextStyle(fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceVisual() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 3, height: 12, decoration: BoxDecoration(color: const Color(0xFFD8B4FE), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Container(width: 3, height: 22, decoration: BoxDecoration(color: const Color(0xFFC084FC), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: Color(0xFF9333EA), shape: BoxShape.circle),
          child: const Center(child: Icon(Icons.mic, color: Colors.white, size: 16)),
        ),
        const SizedBox(width: 6),
        Container(width: 3, height: 22, decoration: BoxDecoration(color: const Color(0xFFC084FC), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Container(width: 3, height: 12, decoration: BoxDecoration(color: const Color(0xFFD8B4FE), borderRadius: BorderRadius.circular(2))),
      ],
    );
  }

  Widget _buildKeypadVisual() {
    return Container(
      width: 52,
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: const Border(bottom: BorderSide(color: Color(0xFF2DD4BF), width: 2)),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(6, (i) {
          final isHighlight = i == 4;
          return Container(
            decoration: BoxDecoration(
              color: isHighlight ? const Color(0xFF14B8A6) : const Color(0xFF334155),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Text(
                "${i + 1}",
                style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTelemetryVisual() {
    return Container(
      width: 64,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(width: 5, height: 14, decoration: const BoxDecoration(color: Color(0xFFEC4899), borderRadius: BorderRadius.vertical(top: Radius.circular(2)))),
          Container(width: 5, height: 24, decoration: const BoxDecoration(color: Color(0xFF38BDF8), borderRadius: BorderRadius.vertical(top: Radius.circular(2)))),
          Container(width: 5, height: 10, decoration: const BoxDecoration(color: Color(0xFFEC4899), borderRadius: BorderRadius.vertical(top: Radius.circular(2)))),
          Container(width: 5, height: 28, decoration: const BoxDecoration(color: Color(0xFF38BDF8), borderRadius: BorderRadius.vertical(top: Radius.circular(2)))),
          Container(width: 5, height: 18, decoration: const BoxDecoration(color: Color(0xFF22D3EE), borderRadius: BorderRadius.vertical(top: Radius.circular(2)))),
        ],
      ),
    );
  }

  Widget _buildCamVisual() {
    return Container(
      width: 64,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: const Border(bottom: BorderSide(color: Color(0xFF22D3EE), width: 2)),
      ),
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF020617),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF22D3EE), width: 1.5),
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: Color(0xFF67E8F9), shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArmVisual() {
    return const Icon(Icons.precision_manufacturing, size: 38, color: Color(0xFF0284C7));
  }

  Widget _buildGyroVisual() {
    return const Icon(Icons.screen_rotation, size: 36, color: Color(0xFF0284C7));
  }
}

class _ToolCardData {
  final String title;
  final Color gradientStart;
  final Color gradientEnd;
  final Color iconColor;
  final Widget visualWidget;
  final Widget screen;

  _ToolCardData({
    required this.title,
    required this.gradientStart,
    required this.gradientEnd,
    required this.iconColor,
    required this.visualWidget,
    required this.screen,
  });
}

class _LedBulb extends StatelessWidget {
  final Color color;
  const _LedBulb(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(140),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
