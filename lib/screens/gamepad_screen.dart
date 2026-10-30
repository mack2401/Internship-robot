import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class GamepadScreen extends StatefulWidget {
  const GamepadScreen({super.key});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> {
  final RobotState state = RobotState();
  bool isConnected = true;
  bool isPaused = false;
  String currentMode = 'arrows'; // 'arrows' or 'joystick'
  String activeOutput = 'IDLE';
  String? toastMessage;

  // Joystick position
  Offset _joystickOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _showToast(String msg) {
    setState(() {
      toastMessage = msg;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          if (toastMessage == msg) toastMessage = null;
        });
      }
    });
  }

  void _sendCommand(String key, String name) {
    final bool devConnected = isConnected || state.isConnected || state.wifiService.isConnected;
    if (!devConnected) {
      _showToast('Device Disconnected — Command Ignored');
      return;
    }
    if (isPaused && name != 'START') {
      _showToast('Gamepad Paused — Press START');
      return;
    }
    setState(() {
      activeOutput = key;
    });
    _showToast('Key: $name');
    state.addLog(LogType.cmd, 'GAMEPAD: $key ($name)');
    // Translate gamepad directions to movement chars (U->F/1, D->B/2, L->L/3, R->R/4)
    String outKey = key;
    if (state.useNumericMotionCommands) {
      if (key == 'U' || key == 'F') {
        outKey = '1';
      } else if (key == 'D' || key == 'B') {
        outKey = '2';
      } else if (key == 'L') {
        outKey = '3';
      } else if (key == 'R') {
        outKey = '4';
      } else if (key == 'S') {
        outKey = '0';
      }
    } else {
      if (key == 'U') {
        outKey = 'F';
      }
      if (key == 'D') {
        outKey = 'B';
      }
    }
    state.sendPayload("$outKey\n");
  }

  void _releaseCommand(String key) {
    if (activeOutput == key) {
      setState(() {
        activeOutput = 'IDLE';
      });
      // Send halt on directional release
      if (key == 'U' || key == 'D' || key == 'L' || key == 'R' || key == 'F' || key == 'B' || key == 'J') {
        state.sendPayload(state.useNumericMotionCommands ? "0\n" : "S\n");
      }
    }
  }

  void _showCodeSnippet() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.code, color: Color(0xFF0D9488), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Arduino / ESP32 Gamepad Protocol',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF0F172A),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '// Sample BLE characteristic packet reception:',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '''void onPacketReceived(char cmd) {
  switch(cmd) {
    case 'U': moveForward(); break;
    case 'D': moveBackward(); break;
    case 'L': turnLeft(); break;
    case 'R': turnRight(); break;
    case 'J': handleAnalog(joyX, joyY); break;
    case 'T': actionTriangle(); break;
    case 'S': actionSquare(); break;
    case 'C': actionCircle(); break;
    case 'X': actionCross(); break;
    case '1': enableMotors(); break;
    case '0': haltMotors(); break;
  }
}''',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF5EEAD4), height: 1.4),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFF8FAFC),
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 44,
          backgroundColor: Colors.white.withOpacity(0.95),
          leading: Padding(
            padding: const EdgeInsets.all(6.0),
            child: InkWell(
              onTap: () {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF334155)),
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text(
                  'Virtual Gamepad',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'BLE Connected' : 'Offline',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Protocol Switcher Badge
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    state.toggleMotionCommandProtocol();
                  });
                  _showToast(state.useNumericMotionCommands
                      ? "Protocol: 1/2/3/4/0 (Mecanum/Numeric)"
                      : "Protocol: F/B/L/R/S (Standard)");
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: state.useNumericMotionCommands ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: state.useNumericMotionCommands ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        state.useNumericMotionCommands ? Icons.pin : Icons.font_download,
                        size: 13,
                        color: state.useNumericMotionCommands ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.useNumericMotionCommands ? '1 2 3 4 0' : 'F B L R S',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: state.useNumericMotionCommands ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Connection Toggle Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    isConnected = !isConnected;
                  });
                  _showToast(isConnected ? 'Device Connected' : 'Device Disconnected');
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bluetooth,
                        size: 14,
                        color: isConnected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? 'On' : 'Off',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Code Snippet Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
              child: InkWell(
                onTap: _showCodeSnippet,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.code, size: 15, color: Color(0xFF334155)),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT CONTROL WELL: D-PAD or JOYSTICK (flex 4)
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLeftWell(),
                              const SizedBox(height: 8),
                              _buildModeDropdown(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // CENTER CONSOLE: STATUS + START & PAUSE CONTROLS (flex 3)
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildCenterStatusBadge(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // RIGHT ACTION PAD: PLAYSTATION ACTIONS (flex 4)
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildRightActionWell(),
                              const SizedBox(height: 8),
                              const Text(
                                'ACTION KEYS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF64748B),
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
            ),
            // Toast Banner Overlay
            if (toastMessage != null)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      toastMessage!,
                      style: const TextStyle(
                        color: Color(0xFF115E59),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftWell() {
    return Container(
      width: 216,
      height: 216,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
        ),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: currentMode == 'arrows' ? _buildDpadCluster() : _buildJoystickCluster(),
    );
  }

  Widget _buildDpadCluster() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // UP
        Positioned(
          top: 8,
          child: _buildGlossyButton(
            icon: Icons.keyboard_arrow_up,
            keyId: 'U',
            name: 'UP',
          ),
        ),
        // DOWN
        Positioned(
          bottom: 8,
          child: _buildGlossyButton(
            icon: Icons.keyboard_arrow_down,
            keyId: 'D',
            name: 'DOWN',
          ),
        ),
        // LEFT
        Positioned(
          left: 8,
          child: _buildGlossyButton(
            icon: Icons.keyboard_arrow_left,
            keyId: 'L',
            name: 'LEFT',
          ),
        ),
        // RIGHT
        Positioned(
          right: 8,
          child: _buildGlossyButton(
            icon: Icons.keyboard_arrow_right,
            keyId: 'R',
            name: 'RIGHT',
          ),
        ),
        // Center Pivot
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
            ),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF94A3B8).withOpacity(0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoystickCluster() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = constraints.maxWidth / 2;
        return GestureDetector(
          onPanUpdate: (details) {
            final local = details.localPosition;
            final center = Offset(radius, radius);
            final delta = local - center;
            final maxDistance = radius - 45;
            final distance = delta.distance;
            final clampedDelta = distance > maxDistance ? delta * (maxDistance / distance) : delta;
            setState(() {
              _joystickOffset = clampedDelta;
            });
            // Update output based on angle
            final normX = clampedDelta.dx / maxDistance;
            final normY = clampedDelta.dy / maxDistance;
            state.setThrottle(-normY);
            state.setSteering(normX);

            String joyDir = 'S';
            if (distance > maxDistance * 0.28) {
              if (normY.abs() > normX.abs()) {
                joyDir = normY < 0 ? 'F' : 'B';
              } else {
                joyDir = normX < 0 ? 'L' : 'R';
              }
            }
            if (activeOutput != joyDir) {
              activeOutput = joyDir;
              state.sendCarMotionCommand(joyDir);
              state.addLog(LogType.cmd, 'JOY: $joyDir');
            }
          },
          onPanEnd: (_) {
            setState(() {
              _joystickOffset = Offset.zero;
              activeOutput = 'IDLE';
            });
            state.setThrottle(0);
            state.setSteering(0);
            state.sendCarMotionCommand("S");
          },
          onPanCancel: () {
            setState(() {
              _joystickOffset = Offset.zero;
              activeOutput = 'IDLE';
            });
            state.setThrottle(0);
            state.setSteering(0);
            state.sendCarMotionCommand("S");
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Crosshair lines
              Container(width: double.infinity, height: 1, color: const Color(0xFFCBD5E1)),
              Container(width: 1, height: double.infinity, color: const Color(0xFFCBD5E1)),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.5)),
                ),
              ),
              // Joystick Thumb
              Transform.translate(
                offset: _joystickOffset,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [Colors.white, Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF1F5F9),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRightActionWell() {
    return Container(
      width: 216,
      height: 216,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
        ),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // TRIANGLE (Top)
          Positioned(
            top: 8,
            child: _buildPlayStationButton(
              symbol: '▲',
              keyId: 'T',
              name: 'TRIANGLE',
              color: const Color(0xFF10B981),
            ),
          ),
          // CROSS (Bottom)
          Positioned(
            bottom: 8,
            child: _buildPlayStationButton(
              symbol: '✖',
              keyId: 'X',
              name: 'CROSS',
              color: const Color(0xFF3B82F6),
            ),
          ),
          // SQUARE (Left)
          Positioned(
            left: 8,
            child: _buildPlayStationButton(
              symbol: '■',
              keyId: 'S',
              name: 'SQUARE',
              color: const Color(0xFFEC4899),
            ),
          ),
          // CIRCLE (Right)
          Positioned(
            right: 8,
            child: _buildPlayStationButton(
              symbol: '●',
              keyId: 'C',
              name: 'CIRCLE',
              color: const Color(0xFFEF4444),
            ),
          ),
          // Center Pivot
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
              ),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF94A3B8).withOpacity(0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlossyButton({required IconData icon, required String keyId, required String name}) {
    final isPressed = activeOutput == keyId;
    return GestureDetector(
      onTapDown: (_) => _sendCommand(keyId, name),
      onTapUp: (_) => _releaseCommand(keyId),
      onTapCancel: () => _releaseCommand(keyId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isPressed
              ? const RadialGradient(
                  center: Alignment(0.1, 0.1),
                  colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                )
              : const RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  colors: [Colors.white, Colors.white, Color(0xFFF1F5F9)],
                ),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: isPressed ? const Color(0xFF0D9488) : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayStationButton({
    required String symbol,
    required String keyId,
    required String name,
    required Color color,
  }) {
    final isPressed = activeOutput == keyId;
    return GestureDetector(
      onTapDown: (_) => _sendCommand(keyId, name),
      onTapUp: (_) => _releaseCommand(keyId),
      onTapCancel: () => _releaseCommand(keyId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isPressed
              ? const RadialGradient(
                  center: Alignment(0.1, 0.1),
                  colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                )
              : const RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  colors: [Colors.white, Colors.white, Color(0xFFF1F5F9)],
                ),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isPressed ? color : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeDropdown() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() {
          currentMode = val;
        });
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'arrows',
          child: Row(
            children: [
              const Icon(Icons.open_with, size: 16, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              const Text('Directional Arrows', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (currentMode == 'arrows')
                const Icon(Icons.check, size: 16, color: Color(0xFF0D9488)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'joystick',
          child: Row(
            children: [
              const Icon(Icons.radio_button_checked, size: 16, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              const Text('Movable Joystick', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (currentMode == 'joystick')
                const Icon(Icons.check, size: 16, color: Color(0xFF0D9488)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentMode == 'arrows' ? Icons.open_with : Icons.radio_button_checked,
              size: 14,
              color: const Color(0xFF0D9488),
            ),
            const SizedBox(width: 6),
            Text(
              currentMode == 'arrows' ? 'Directional Arrows' : 'Movable Joystick',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'STATE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isPaused ? 'PAUSED' : 'ACTIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPaused ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
              letterSpacing: 1.2,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            width: 36,
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
          const Text(
            'OUTPUT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            activeOutput,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          // START BUTTON
          InkWell(
            onTap: () {
              setState(() {
                isPaused = false;
              });
              _sendCommand('1', 'START');
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'START',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // PAUSE BUTTON
          InkWell(
            onTap: () {
              setState(() {
                isPaused = true;
              });
              _sendCommand('0', 'PAUSE');
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: const Color(0xFFF1F5F9),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause, size: 12, color: Color(0xFF475569)),
                  SizedBox(width: 4),
                  Text(
                    'PAUSE',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
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
}
