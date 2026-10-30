import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/state/robot_state.dart';
import '../core/models/device_model.dart';

class CarControllerScreen extends StatefulWidget {
  const CarControllerScreen({super.key});

  @override
  State<CarControllerScreen> createState() => _CarControllerScreenState();
}

class _CarControllerScreenState extends State<CarControllerScreen> {
  final RobotState state = RobotState();

  // Multi-touch active command set ('F', 'B', 'L', 'R')
  final Set<String> _activeCommands = {};

  bool _isEmergencyStopped = false;
  bool _isHornPressed = false;
  Timer? _danceTimer;
  int _danceStep = 0;

  String? _toastMessage;
  Timer? _toastTimer;

  static const String _chevronImageUrl =
      "https://lh3.googleusercontent.com/aida-public/AB6AXuDyEMc9YXP1P8iafUc7m1F5EAAtUfQP0Mmoej5t0wInCeQwFlTVIbdwm_xJUh3eBZ87MXf5-Cv6QV_YSCiWOCle8qU-2_W5-zxvL0fedqpTmaeifgP7WNDL-MNKHpL8Lzr4tg3BCMoN5i4ySiEhOCJpIZ-3McJywKapeNIVsydFDwLF2bT5SYs3IvWJkDXKObQlnSbIsTZoI7WKWOAZFa0sbRFXsq8L9mZ9DQYv6AQDZAdNMHBX5ljynCqd4LyW0bvLU2s";

  final List<List<String>> _danceSteps = const [
    ['F', 'L'],
    ['B', 'R'],
    ['F', 'R'],
    ['B', 'L'],
    ['F'],
    ['B'],
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _danceTimer?.cancel();
    _toastTimer?.cancel();
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  // Multi-touch command handlers
  void _startCommand(String cmd) {
    if (_danceTimer != null) _stopDanceMode();
    _isEmergencyStopped = false;
    _activeCommands.add(cmd);
    HapticFeedback.lightImpact();
    _syncCommandsToRobot();
    setState(() {});
  }

  void _stopCommand(String cmd) {
    _activeCommands.remove(cmd);
    _syncCommandsToRobot();
    setState(() {});
  }

  void _syncCommandsToRobot() {
    double throttle = 0.0;
    double steering = 0.0;
    final capRatio = state.speedCap / 100.0;

    String currentDriveChar = 'S';
    if (_activeCommands.contains('F')) {
      throttle += capRatio;
      currentDriveChar = 'F';
    } else if (_activeCommands.contains('B')) {
      throttle -= capRatio;
      currentDriveChar = 'B';
    } else if (_activeCommands.contains('L')) {
      steering -= 0.8;
      currentDriveChar = 'L';
    } else if (_activeCommands.contains('R')) {
      steering += 0.8;
      currentDriveChar = 'R';
    } else {
      currentDriveChar = 'S';
    }

    state.setThrottle(throttle);
    state.setSteering(steering);
    state.sendCarMotionCommand(currentDriveChar);

    if (_activeCommands.isNotEmpty) {
      state.addTerminalLog(">>> CAR_CMD: ${_activeCommands.join('+')} ($currentDriveChar)", LogType.tx);
    }
  }

  void _triggerEmergencyStop() {
    _activeCommands.clear();
    _stopDanceMode();
    _isEmergencyStopped = true;
    state.triggerEmergencyBrake();
    HapticFeedback.heavyImpact();
    _showToast("Emergency Motors Brake Activated");
    setState(() {});
  }

  void _toggleDanceMode() {
    if (_danceTimer != null) {
      _stopDanceMode();
      _showToast("Dance routine stopped");
    } else {
      _isEmergencyStopped = false;
      _danceStep = 0;
      _showToast("Choreography Routine Started!");
      state.toggleDanceMode();

      _danceTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
        _activeCommands.clear();
        final currentStep = _danceSteps[_danceStep % _danceSteps.length];
        for (var cmd in currentStep) {
          _activeCommands.add(cmd);
        }
        _syncCommandsToRobot();
        _danceStep++;
        if (mounted) setState(() {});
      });
      setState(() {});
    }
  }

  void _stopDanceMode() {
    _danceTimer?.cancel();
    _danceTimer = null;
    _activeCommands.clear();
    _syncCommandsToRobot();
    if (state.danceMode) state.toggleDanceMode();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Compact Top Header Bar
                  _buildTopHeaderBar(),
                  // Main Horizontal Controller Arena
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // LEFT POD: Forward & Backward (col-span-4)
                          Expanded(
                            flex: 4,
                            child: _buildLeftPod(),
                          ),
                          const SizedBox(width: 12),
                          // CENTER POD: Sleek & Compact Utility Column (col-span-4)
                          Expanded(
                            flex: 4,
                            child: _buildCenterPod(),
                          ),
                          const SizedBox(width: 12),
                          // RIGHT POD: Left Turn & Right Turn (col-span-4)
                          Expanded(
                            flex: 4,
                            child: _buildRightPod(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Floating Quick Toast matching Stitch HTML
              if (_toastMessage != null)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withAlpha(235),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Text(
                            _toastMessage!,
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- COMPACT TOP HEADER BAR ---
  Widget _buildTopHeaderBar() {
    final dev = state.currentDevice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Navigation & Identity
          Flexible(
            flex: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                      DeviceOrientation.portraitDown,
                    ]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Color(0xFF0369A1), size: 17),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    "Car Controller",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dev.isConnected) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "CONNECTED • ${dev.protocol}",
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    state.toggleMotionCommandProtocol();
                    _showToast(state.useNumericMotionCommands
                        ? "Protocol: 1/2/3/4/0 (Mecanum/Numeric)"
                        : "Protocol: F/B/L/R/S (Standard)");
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: state.useNumericMotionCommands ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: state.useNumericMotionCommands ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 11,
                          color: state.useNumericMotionCommands ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          state.useNumericMotionCommands ? "CMD: 1 2 3 4 0" : "CMD: F B L R S",
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: state.useNumericMotionCommands ? const Color(0xFF0369A1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Center: Speed Cap Trim Slider
          Container(
            constraints: const BoxConstraints(maxWidth: 270),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "SPEED CAP",
                      style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                    ),
                    Text(
                      "${state.speedCap.toInt()}% (${state.driveMode})",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF0284C7),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      thumbColor: const Color(0xFF0284C7),
                    ),
                    child: Slider(
                      value: state.speedCap.clamp(20.0, 100.0),
                      min: 20,
                      max: 100,
                      divisions: 16,
                      onChanged: (val) {
                        state.setSpeedCap(val);
                        _showToast("Speed trim adjusted to ${val.toInt()}%");
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LEFT POD: FORWARD & BACKWARD ---
  Widget _buildLeftPod() {
    final isForward = _activeCommands.contains('F');
    final isBackward = _activeCommands.contains('B');

    return Column(
      children: [
        // Forward Button
        Expanded(
          child: _buildThumbButton(
            cmdCode: 'F',
            isActive: isForward,
            quarterTurns: 3, // -90 deg
            label: "Forward",
          ),
        ),
        const SizedBox(height: 10),
        // Backward Button
        Expanded(
          child: _buildThumbButton(
            cmdCode: 'B',
            isActive: isBackward,
            quarterTurns: 1, // 90 deg
            label: "Backward",
          ),
        ),
      ],
    );
  }

  // --- RIGHT POD: LEFT TURN & RIGHT TURN ---
  Widget _buildRightPod() {
    final isLeft = _activeCommands.contains('L');
    final isRight = _activeCommands.contains('R');

    return Row(
      children: [
        // Left Turn Button
        Expanded(
          child: _buildThumbButton(
            cmdCode: 'L',
            isActive: isLeft,
            quarterTurns: 2, // 180 deg
            label: "Left Turn",
          ),
        ),
        const SizedBox(width: 10),
        // Right Turn Button
        Expanded(
          child: _buildThumbButton(
            cmdCode: 'R',
            isActive: isRight,
            quarterTurns: 0, // 0 deg
            label: "Right Turn",
          ),
        ),
      ],
    );
  }

  // --- CENTER POD: COMPACT UTILITIES ---
  Widget _buildCenterPod() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: SizedBox(
        width: 210,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Status Micro Pill
            _buildMotionStatusPill(),
            const SizedBox(height: 6),

        // Emergency STOP Button
        GestureDetector(
          onTap: _triggerEmergencyStop,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 210),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x33DC2626), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pan_tool, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  "STOP",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Horn Button (Press & Hold)
        const SizedBox(height: 6),
        Listener(
          onPointerDown: (_) {
            setState(() => _isHornPressed = true);
            state.setHorn(true);
            HapticFeedback.mediumImpact();
            _showToast("BEEP! Horn Active");
          },
          onPointerUp: (_) {
            setState(() => _isHornPressed = false);
            state.setHorn(false);
          },
          onPointerCancel: (_) {
            setState(() => _isHornPressed = false);
            state.setHorn(false);
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 210),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
            decoration: BoxDecoration(
              color: _isHornPressed ? const Color(0xFFF1F5F9) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign,
                  size: 17,
                  color: _isHornPressed ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
                ),
                const SizedBox(width: 6),
                const Text(
                  "HORN",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ),

        // Light Toggle Button
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            state.toggleHeadlights();
            _showToast(state.headlights ? "LED Headlights Activated" : "LED Headlights Deactivated");
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 210),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.light_mode,
                      size: 16,
                      color: state.headlights ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.headlights ? "LIGHTS ON" : "LIGHTS OFF",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: state.headlights ? const Color(0xFFD97706) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: state.headlights ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Dance Mode Choreography Button
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _toggleDanceMode,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 210),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
            decoration: BoxDecoration(
              color: _danceTimer != null ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _danceTimer != null ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.smart_toy,
                      size: 16,
                      color: _danceTimer != null ? Colors.white : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "DANCE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: _danceTimer != null ? Colors.white : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                Text(
                  _danceTimer != null ? "Active" : "Auto Ready",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _danceTimer != null ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotionStatusPill() {
    if (_isEmergencyStopped) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 6, color: Color(0xFFDC2626)),
            SizedBox(width: 5),
            Text(
              "EMERGENCY HALT",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontFamily: 'monospace'),
            ),
          ],
        ),
      );
    }

    if (_activeCommands.isEmpty) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withAlpha(160),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 6, color: Color(0xFF0284C7)),
            SizedBox(width: 5),
            Text(
              "IDLE • STANDBY",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569), fontFamily: 'monospace'),
            ),
          ],
        ),
      );
    }

    final parts = <String>[];
    if (_activeCommands.contains('F')) parts.add('FORWARD');
    if (_activeCommands.contains('B')) parts.add('REVERSE');
    if (_activeCommands.contains('L')) parts.add('STEER-L');
    if (_activeCommands.contains('R')) parts.add('STEER-R');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            parts.join(' + '),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  // --- THUMB BUTTON WITH ROTATED GRAPHIC ---
  Widget _buildThumbButton({
    required String cmdCode,
    required bool isActive,
    required int quarterTurns,
    required String label,
  }) {
    return Listener(
      onPointerDown: (_) => _startCommand(cmdCode),
      onPointerUp: (_) => _stopCommand(cmdCode),
      onPointerCancel: (_) => _stopCommand(cmdCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? const Color(0x330284C7) : const Color(0x060F172A),
              blurRadius: isActive ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: Image.network(
              _chevronImageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              color: isActive ? Colors.white : const Color(0xFF0284C7),
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.arrow_forward_rounded,
                size: 42,
                color: isActive ? Colors.white : const Color(0xFF0284C7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
