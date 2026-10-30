import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class LedLampScreen extends StatefulWidget {
  const LedLampScreen({super.key});

  @override
  State<LedLampScreen> createState() => _LedLampScreenState();
}

class _LedLampScreenState extends State<LedLampScreen> {
  final RobotState state = RobotState();

  int _activeTab = 0; // 0: Lamp Control, 1: Choose Color
  bool _isLampOn = false;
  double _lampPwm = 100.0; // 0 to 100

  // RGB State
  int _r = 0;
  int _g = 210;
  int _b = 255;
  String _hexString = "#00D2FF";
  Offset _handleOffset = const Offset(178, 78);
  bool _isTransmitting = false;

  final List<Color> _presetColors = const [
    Color(0xFFFF3131), // Crimson Red
    Color(0xFFFF9100), // Amber Glow
    Color(0xFFFFDE59), // Warm Gold
    Color(0xFF00D2FF), // Cyan Sky
    Color(0xFF7E3AF2), // Electric Violet
    Color(0xFFFFFFFF), // Clean White
  ];

  @override
  void initState() {
    super.initState();
    _isLampOn = state.lampPower;
    _lampPwm = state.lampBrightness;
    _applyColor(state.lampColor);
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

  void _applyColor(Color c) {
    _r = (c.r * 255).toInt();
    _g = (c.g * 255).toInt();
    _b = (c.b * 255).toInt();
    _hexString =
        '#${_r.toRadixString(16).padLeft(2, '0')}${_g.toRadixString(16).padLeft(2, '0')}${_b.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();

    // Calculate approximate handle offset on 240px wheel (radius 120)
    final hsv = HSVColor.fromColor(c);
    final rad = (hsv.hue - 90) * (pi / 180.0);
    final dist = hsv.saturation * 100;
    _handleOffset = Offset(120 + cos(rad) * dist, 120 + sin(rad) * dist);
  }

  void _toggleLamp() {
    setState(() {
      _isLampOn = !_isLampOn;
    });
    state.toggleLampPower();
    HapticFeedback.lightImpact();
    state.addTerminalLog(
        ">>> LAMP_POWER: ${_isLampOn ? 1 : 0} (CMD: '${_isLampOn ? 1 : 0}')",
        LogType.tx);
  }

  void _onWheelInteraction(Offset localPos, double wheelSize) {
    final center = Offset(wheelSize / 2, wheelSize / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final radius = (wheelSize / 2) - 8;
    final dist = min(sqrt(dx * dx + dy * dy), radius);

    final angle = (atan2(dy, dx) * (180.0 / pi) + 90.0 + 360.0) % 360.0;
    final hue = angle;
    final sat = (dist / radius).clamp(0.0, 1.0);
    final val = 1.0;

    final color = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();

    final rad = (angle - 90.0) * (pi / 180.0);
    final handleX = center.dx + cos(rad) * dist;
    final handleY = center.dy + sin(rad) * dist;

    setState(() {
      _handleOffset = Offset(handleX, handleY);
      _r = (color.r * 255).toInt();
      _g = (color.g * 255).toInt();
      _b = (color.b * 255).toInt();
      _hexString =
          '#${_r.toRadixString(16).padLeft(2, '0')}${_g.toRadixString(16).padLeft(2, '0')}${_b.toRadixString(16).padLeft(2, '0')}'
              .toUpperCase();
    });
  }

  void _transmitColorArray() {
    setState(() => _isTransmitting = true);
    final color = Color.fromRGBO(_r, _g, _b, 1.0);
    state.setLampColor(color);
    state.addTerminalLog(
        ">>> RGB_STREAM: R:$_r G:$_g B:$_b ($_hexString)", LogType.tx);
    HapticFeedback.mediumImpact();

    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _isTransmitting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = Color.fromRGBO(_r, _g, _b, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Fixed System Header with Title, Sound, Settings & Segmented Tab
            _buildFixedHeader(),
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 12, bottom: 90),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _activeTab == 0
                        ? _buildLampControlPanel()
                        : _buildRgbColorPanel(currentColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FIXED TOP HEADER ---
  Widget _buildFixedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB).withAlpha(245),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(
              color: Color(0x050F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Back pill, Title, Quick Actions (Sound & Settings)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 4,
                              offset: Offset(0, 1)),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back,
                              size: 16, color: Color(0xFF1B1C1D)),
                          SizedBox(width: 4),
                          Text(
                            "Back",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B1C1D)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _activeTab == 0 ? "LED / Lamp" : "RGB Control",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1C1D)),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "— iBots",
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5A5F63),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Segmented Tab Toggle (Lamp Control & Choose Color)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEDEE).withAlpha(180),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFCBD5E1).withAlpha(120)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _activeTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: _activeTab == 0
                            ? const [
                                BoxShadow(
                                    color: Color(0x0C000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1)),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb,
                            size: 16,
                            color: _activeTab == 0
                                ? const Color(0xFF094CB2)
                                : const Color(0xFF5A5F63),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Lamp Control",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTab == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _activeTab == 0
                                  ? const Color(0xFF094CB2)
                                  : const Color(0xFF5A5F63),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _activeTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: _activeTab == 1
                            ? const [
                                BoxShadow(
                                    color: Color(0x0C000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1)),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.palette,
                            size: 16,
                            color: _activeTab == 1
                                ? const Color(0xFF094CB2)
                                : const Color(0xFF5A5F63),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "RGB Control",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTab == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _activeTab == 1
                                  ? const Color(0xFF094CB2)
                                  : const Color(0xFF5A5F63),
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
        ],
      ),
    );
  }

  // --- VIEW 1: LAMP CONTROL PANEL ---
  Widget _buildLampControlPanel() {
    final intensity = _lampPwm / 100.0;

    return Column(
      children: [
        // Main Prominent Lamp State Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              // Big Interactive Bulb Graphic with Dynamic Ambient Glow
              Stack(
                alignment: Alignment.center,
                children: [
                  // Ambient glow halo when ON
                  if (_isLampOn)
                    Container(
                      width: 270,
                      height: 270,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B)
                                .withAlpha((120 * intensity).toInt()),
                            blurRadius: 50 * intensity,
                            spreadRadius: 20 * intensity,
                          ),
                        ],
                      ),
                    ),
                  // Bulb Button
                  GestureDetector(
                    onTap: _toggleLamp,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isLampOn
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF5F3F4).withAlpha(200),
                        border: Border.all(
                          color: _isLampOn
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFCBD5E1),
                          width: _isLampOn ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isLampOn
                                ? const Color(0xFFF59E0B)
                                    .withAlpha((140 * intensity).toInt())
                                : const Color(0x0A000000),
                            blurRadius: _isLampOn ? 35 * intensity : 8,
                            spreadRadius: _isLampOn ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb,
                            size: 92,
                            color: _isLampOn
                                ? const Color(0xFFD97706)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "TAP TO TOGGLE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: _isLampOn
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Status text
              Text(
                _isLampOn ? "LAMP IS ON" : "LAMP IS OFF",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: _isLampOn
                      ? const Color(0xFFD97706)
                      : const Color(0xFF1B1C1D),
                ),
              ),
              const SizedBox(height: 8),
              // Active Command badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _isLampOn
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEFEDEE),
                  borderRadius: BorderRadius.circular(30),
                  border: _isLampOn
                      ? Border.all(color: const Color(0xFFFCD34D))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Active Command: ",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isLampOn
                            ? const Color(0xFFB45309)
                            : const Color(0xFF5A5F63),
                      ),
                    ),
                    Text(
                      "[ ${_isLampOn ? '1' : '0'} ]",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isLampOn
                            ? const Color(0xFFB45309)
                            : const Color(0xFF1B1C1D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Intensity / PWM Slider Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 6,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.brightness_medium,
                          size: 20, color: Color(0xFF094CB2)),
                      SizedBox(width: 8),
                      Text(
                        "Lamp Intensity",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1C1D)),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${_lampPwm.toInt()}%",
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF094CB2),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: const Color(0xFF094CB2),
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: _lampPwm.clamp(0.0, 100.0),
                  min: 0,
                  max: 100,
                  onChanged: (val) {
                    setState(() => _lampPwm = val);
                    state.setLampBrightness(val);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- VIEW 2: RGB COLOR PICKER PANEL ---
  Widget _buildRgbColorPanel(Color currentColor) {
    const double wheelSize = 240.0;

    return Column(
      children: [
        // Chromatic Spectrum Wheel Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.palette, size: 20, color: Color(0xFF094CB2)),
                      SizedBox(width: 8),
                      Text(
                        "Chromatic Spectrum",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1C1D)),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEDEE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: currentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _hexString,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1C1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Interactive Chromatic Wheel Container with Reticle Handle
              GestureDetector(
                onPanDown: (details) =>
                    _onWheelInteraction(details.localPosition, wheelSize),
                onPanUpdate: (details) =>
                    _onWheelInteraction(details.localPosition, wheelSize),
                child: SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Conic Gradient Wheel Graphic
                      Container(
                        width: wheelSize,
                        height: wheelSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              Color(0xFFFF0000),
                              Color(0xFFFF8800),
                              Color(0xFFFFFF00),
                              Color(0xFF00FF00),
                              Color(0xFF00FFFF),
                              Color(0xFF0066FF),
                              Color(0xFF9900FF),
                              Color(0xFFFF0099),
                              Color(0xFFFF0000),
                            ],
                          ),
                          border: Border.all(
                              color: const Color(0xFFCBD5E1), width: 1),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 14,
                                offset: Offset(0, 4)),
                          ],
                        ),
                      ),
                      // Smooth Radial Fade towards white center
                      Container(
                        width: wheelSize,
                        height: wheelSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withAlpha(240),
                              Colors.white.withAlpha(160),
                              Colors.transparent,
                            ],
                            stops: const [0.08, 0.38, 0.72],
                          ),
                        ),
                      ),
                      // Center Color Eyedropper Sample Point
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: currentColor,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 8,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.colorize,
                            size: 20, color: Colors.white),
                      ),
                      // Draggable Reticle Selector Handle
                      Positioned(
                        left: _handleOffset.dx - 14,
                        top: _handleOffset.dy - 14,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFCBD5E1), width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: currentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // RGB 3-Channel Breakdown Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 6,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "RGB CHANNELS",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A5F63)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildRgbChannelColumn("RED", _r, const Color(0xFFE11D48)),
                  const SizedBox(width: 10),
                  _buildRgbChannelColumn("GREEN", _g, const Color(0xFF059669)),
                  const SizedBox(width: 10),
                  _buildRgbChannelColumn("BLUE", _b, const Color(0xFF0284C7)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Quick Preset Swatches (Archival Presets)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 6,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ARCHIVAL PRESETS",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5A5F63)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _presetColors.map((color) {
                  final isSelected = currentColor.value == color.value;
                  return GestureDetector(
                    onTap: () => setState(() => _applyColor(color)),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF094CB2)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha(80),
                            blurRadius: isSelected ? 8 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Transmission Primary Button
        GestureDetector(
          onTap: _transmitColorArray,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isTransmitting
                    ? const [Color(0xFF059669), Color(0xFF10B981)]
                    : const [Color(0xFF094CB2), Color(0xFF3366CC)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (_isTransmitting
                          ? const Color(0xFF059669)
                          : const Color(0xFF094CB2))
                      .withAlpha(80),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isTransmitting ? Icons.check_circle : Icons.send_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _isTransmitting
                      ? "Color Sent!"
                      : "Send",
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRgbChannelColumn(String title, int val, Color color) {
    final pct = (val / 255.0).clamp(0.0, 1.0);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              "$val",
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1C1D)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 4,
                color: const Color(0xFFE2E8F0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(color: color),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
