import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'devices_screen.dart';
import 'code_examples_screen.dart';
import 'settings_screen.dart';
import 'car_controller_screen.dart';
import 'gamepad_screen.dart';
import 'telemetry_screen.dart';
import 'led_lamp_screen.dart';
import 'switch_panel_screen.dart';
import 'terminal_screen.dart';
import 'voice_control_screen.dart';
import 'keypad_screen.dart';
import 'robotic_arm_screen.dart';
import 'gyro_control_screen.dart';
import 'esp32_cam_screen.dart';
import 'profile_screen.dart';
import 'help_support_screen.dart';
import 'getting_started_screen.dart';
import 'contact_support_screen.dart';
import 'about_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    DevicesScreen(),
    CodeExamplesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildTacticalDrawer(context),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          // Docked Bottom Navigation Bar matching Stitch HTML
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStitchBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchBottomBar() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, "Home", Icons.home_rounded),
                _buildNavItem(1, "Devices", Icons.memory_rounded),
                _buildNavItem(2, "Code", Icons.terminal_rounded),
                _buildNavItem(3, "Settings", Icons.settings_rounded),
              ],
            ),
            const SizedBox(height: 4),
            // Home Indicator Notch
            Container(
              width: 100,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withAlpha(160),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "iBots Remote",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        "ALL 20 SYSTEMS READY",
                        style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerSection("PRIMARY CONTROLLERS"),
                  _buildDrawerItem(context, Icons.directions_car, "Car Controller", const CarControllerScreen()),
                  _buildDrawerItem(context, Icons.sports_esports, "Virtual Gamepad", const GamepadScreen()),
                  _buildDrawerItem(context, Icons.dialpad, "Virtual Keypad", const KeypadScreen()),
                  _buildDrawerItem(context, Icons.precision_manufacturing, "Robotic Arm (6-DOF)", const RoboticArmScreen()),
                  _buildDrawerItem(context, Icons.screen_rotation, "Gyro Tilt Control", const GyroControlScreen()),
                  _buildDrawerItem(context, Icons.mic, "Voice Control", const VoiceControlScreen()),

                  _buildDrawerSection("SENSORS & MONITORING"),
                  _buildDrawerItem(context, Icons.videocam, "ESP32-CAM Live Feed", const Esp32CamScreen()),
                  _buildDrawerItem(context, Icons.speed, "Telemetry & Sensors", const TelemetryScreen()),
                  _buildDrawerItem(context, Icons.terminal, "Text Terminal (CLI)", const TerminalScreen()),
                  _buildDrawerItem(context, Icons.palette, "LED & Lamp RGB", const LedLampScreen()),
                  _buildDrawerItem(context, Icons.toggle_on, "Switch Panel Relays", const SwitchPanelScreen()),

                  _buildDrawerSection("SUPPORT & RESOURCES"),
                  _buildDrawerItem(context, Icons.person, "Operator Profile", const ProfileScreen()),
                  _buildDrawerItem(context, Icons.menu_book, "Getting Started Guide", const GettingStartedScreen()),
                  _buildDrawerItem(context, Icons.help_outline, "Help & FAQ Support", const HelpSupportScreen()),
                  _buildDrawerItem(context, Icons.support_agent, "Contact Support Desk", const ContactSupportScreen()),
                  _buildDrawerItem(context, Icons.code, "Firmware Code Examples", const CodeExamplesScreen()),
                  _buildDrawerItem(context, Icons.settings, "System Settings", const SettingsScreen()),
                  _buildDrawerItem(context, Icons.info_outline, "About iBots Remote", const AboutScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 14, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF0284C7)),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, Widget destination) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
    );
  }
}
