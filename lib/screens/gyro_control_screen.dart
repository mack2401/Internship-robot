import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';
import '../core/sensors/sensor_service.dart';

class GyroControlScreen extends StatefulWidget {
  const GyroControlScreen({super.key});

  @override
  State<GyroControlScreen> createState() => _GyroControlScreenState();
}

class _GyroControlScreenState extends State<GyroControlScreen> {
  final RobotState state = RobotState();
  final SensorService _sensorService = SensorService();
  StreamSubscription<SensorData>? _sensorSub;

  double rawPitch = 0.0;
  double rawRoll = 0.0;
  double rawYaw = 0.0;

  double zeroPitch = 0.0;
  double zeroRoll = 0.0;

  double pitch = 0.0;
  double roll = 0.0;
  double yaw = 0.0;

  double steeringSensitivity = 1.5; // 0.5x to 3.0x multiplier
  bool isTransmitting = true;
  String activeDirection = 'S'; // 'F', 'B', 'L', 'R', 'S'
  DateTime _lastHeartbeat = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startSensors();
  }

  Future<void> _startSensors() async {
    await _sensorService.start();
    _sensorSub = _sensorService.sensorStream.listen(_onSensorData);
  }

  void _onSensorData(SensorData data) {
    if (!mounted) return;

    rawPitch = data.pitch;
    rawRoll = data.roll;
    rawYaw = data.yaw;

    // Relative to calibrated neutral orientation
    final relPitch = (rawPitch - zeroPitch);
    final relRoll = (rawRoll - zeroRoll);

    setState(() {
      pitch = relPitch;
      roll = relRoll;
      yaw = rawYaw;
    });

    if (!isTransmitting) return;

    // Dynamic threshold based on sensitivity (higher sensitivity = easier to trigger)
    final threshold = (12.0 / steeringSensitivity).clamp(5.0, 25.0);

    String newDir = 'S';
    if (relPitch < -threshold) {
      newDir = 'F'; // Phone top tilted downward
    } else if (relPitch > threshold) {
      newDir = 'B'; // Phone top tilted upward
    } else if (relRoll < -threshold) {
      newDir = 'L'; // Phone tilted left
    } else if (relRoll > threshold) {
      newDir = 'R'; // Phone tilted right
    } else {
      newDir = 'S'; // Neutral level zone
    }

    final now = DateTime.now();
    // Send when direction changes or periodically as heartbeat for continuous movement
    if (newDir != activeDirection || (newDir != 'S' && now.difference(_lastHeartbeat).inMilliseconds > 350)) {
      activeDirection = newDir;
      _lastHeartbeat = now;
      state.sendCarMotionCommand(newDir);
      state.addLog(LogType.cmd, 'GYRO: $newDir (P:${pitch.toInt()}° R:${roll.toInt()}°)');
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _sensorService.stop();
    // Always halt motors when exiting gyro screen
    state.sendCarMotionCommand("S");
    super.dispose();
  }

  void _calibrateZero() {
    setState(() {
      zeroPitch = rawPitch;
      zeroRoll = rawRoll;
      pitch = 0.0;
      roll = 0.0;
      activeDirection = 'S';
    });
    state.sendCarMotionCommand("S");
    state.addLog(LogType.cmd, 'GYRO: CALIBRATED NEUTRAL ZERO');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Neutral orientation calibrated to current position (0.0°)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _setSensitivity(double val) {
    setState(() {
      steeringSensitivity = double.parse(val.toStringAsFixed(1));
    });
    state.gyroSensitivity = steeringSensitivity;
    state.addLog(LogType.cmd, 'GYRO: SENSITIVITY ${steeringSensitivity.toStringAsFixed(1)}x');
  }

  String get _sensitivityLabel {
    if (steeringSensitivity <= 1.0) {
      return '${steeringSensitivity.toStringAsFixed(1)}x (Low)';
    } else if (steeringSensitivity <= 1.8) {
      return '${steeringSensitivity.toStringAsFixed(1)}x (Medium)';
    } else {
      return '${steeringSensitivity.toStringAsFixed(1)}x (High)';
    }
  }

  Widget _buildPresetButton(double val, String title, String multiplier) {
    final isSelected = (steeringSensitivity - val).abs() < 0.15;
    return InkWell(
      onTap: () => _setSensitivity(val),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              multiplier,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threshold = (12.0 / steeringSensitivity).clamp(5.0, 25.0);
    final isFwd = pitch < -threshold;
    final isRev = pitch > threshold;
    final isLeft = roll < -threshold;
    final isRight = roll > threshold;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.95),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF1F5F9),
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF334155)),
            ),
          ),
        ),
        title: const Text(
          'Gyro Control',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  state.toggleMotionCommandProtocol();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.useNumericMotionCommands
                        ? "Protocol: 1/2/3/4/0 (Mecanum Robot)"
                        : "Protocol: F/B/L/R/S (Standard Rover)"),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: InkWell(
              onTap: _calibrateZero,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.restart_alt, size: 15, color: Color(0xFF475569)),
                    SizedBox(width: 4),
                    Text(
                      'Center All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. Transmission Status & Toggle Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isTransmitting ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTransmitting ? 'Motion Control Active' : 'Motion Control Paused',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isTransmitting ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isTransmitting,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (val) {
                        setState(() {
                          isTransmitting = val;
                          if (!val) {
                            activeDirection = 'S';
                            state.sendPayload("S\n");
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Interactive Gimbal & Attitude Visualizer Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.explore, size: 16, color: Color(0xFF94A3B8)),
                            SizedBox(width: 6),
                            Text(
                              'Attitude Matrix (Live IMU)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        // Current Active Motion Command Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: activeDirection == 'S'
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: activeDirection == 'S'
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF38BDF8),
                            ),
                          ),
                          child: Text(
                            activeDirection == 'F'
                                ? '▲ FWD (F)'
                                : activeDirection == 'B'
                                    ? '▼ REV (B)'
                                    : activeDirection == 'L'
                                        ? '◄ LEFT (L)'
                                        : activeDirection == 'R'
                                            ? '► RIGHT (R)'
                                            : '● NEUTRAL (S)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: activeDirection == 'S'
                                  ? const Color(0xFF475569)
                                  : const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Virtual Gimbal Horizon Ring Container
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Compass Outer Ring
                          Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activeDirection != 'S'
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                            ),
                          ),
                          // Crosshair lines
                          Container(width: 190, height: 1, color: const Color(0xFFE2E8F0)),
                          Container(width: 1, height: 190, color: const Color(0xFFE2E8F0)),

                          // Direction Pointers (Highlight actively triggered directions)
                          Positioned(
                            top: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFwd ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FWD (F)',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isFwd ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isRev ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'REV (B)',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isRev ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLeft ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'L',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isLeft ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isRight ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'R',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isRight ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),

                          // Real-time 3D Phone Model / Silhouette tilting in response to phone motion
                          Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateX((pitch.clamp(-45.0, 45.0) * 3.14159 / 180.0))
                              ..rotateZ((roll.clamp(-45.0, 45.0) * 3.14159 / 180.0)),
                            alignment: Alignment.center,
                            child: Container(
                              width: 90,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: activeDirection != 'S'
                                      ? [const Color(0xFF0369A1), const Color(0xFF0F172A)]
                                      : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeDirection != 'S'
                                        ? const Color(0xFF0284C7).withOpacity(0.4)
                                        : Colors.black.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF020617),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF020617),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.adjust,
                                          size: 28,
                                          color: activeDirection != 'S'
                                              ? const Color(0xFF38BDF8)
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'IMU 6-DOF',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: activeDirection != 'S'
                                                ? const Color(0xFF7DD3FC)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF475569),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Axis Value Readouts (Bento Row)
                    Row(
                      children: [
                        // Pitch Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isFwd || isRev)
                                    ? const Color(0xFF0284C7)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text('Pitch (X)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 2),
                                Text(
                                  '${pitch.toStringAsFixed(1)}°',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFwd ? '▲ FWD' : isRev ? '▼ REV' : '—',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: (isFwd || isRev) ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Roll Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isLeft || isRight)
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text('Roll (Y)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 2),
                                Text(
                                  '${roll >= 0 ? '+' : ''}${roll.toStringAsFixed(1)}°',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLeft ? '◄ LEFT' : isRight ? '► RIGHT' : '—',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: (isLeft || isRight) ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Yaw Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text('Yaw (Z)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 2),
                                Text(
                                  '${yaw.toStringAsFixed(1)}°',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                const Text('COMPASS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Tuning & Sensitivity Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, size: 18, color: Color(0xFF0284C7)),
                            SizedBox(width: 8),
                            Text(
                              'Steering Sensitivity',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _sensitivityLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                      ),
                      child: Slider(
                        value: steeringSensitivity.clamp(0.5, 3.0),
                        min: 0.5,
                        max: 3.0,
                        divisions: 25,
                        activeColor: const Color(0xFF0284C7),
                        inactiveColor: const Color(0xFFE2E8F0),
                        onChanged: (val) => _setSensitivity(val),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick-Select Sensitivity Preset Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildPresetButton(0.8, 'Low', '0.8x'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(1.5, 'Medium', '1.5x'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(2.4, 'High', '2.4x'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _calibrateZero,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.my_location, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text(
                              'Calibrate Neutral Zero',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
