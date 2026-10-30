import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({super.key});

  @override
  State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen> with SingleTickerProviderStateMixin {
  final RobotState state = RobotState();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isSpeechInitialized = false;
  bool isListening = false;
  String recognizedText = "";
  String? lastExecutedAction;
  String? errorMessage;
  double _soundLevel = 0.0;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    state.addListener(_onStateChange);
    _initSpeechRecognizer();
  }

  @override
  void dispose() {
    _waveController.dispose();
    state.removeListener(_onStateChange);
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initSpeechRecognizer() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("[SpeechToText] Status: $status");
          if (status == 'done' || status == 'notListening') {
            if (mounted && isListening) {
              setState(() {
                isListening = false;
              });
              if (recognizedText.isNotEmpty) {
                _processCommand(recognizedText);
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("[SpeechToText] Error: ${errorNotification.errorMsg}");
          if (mounted) {
            setState(() {
              isListening = false;
              if (errorNotification.errorMsg.isNotEmpty && errorNotification.errorMsg != "error_no_match") {
                errorMessage = errorNotification.errorMsg;
              }
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isSpeechInitialized = available;
        });
      }
    } catch (e) {
      debugPrint("[SpeechToText] Init exception: $e");
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionSettingsDialog();
      }
      return false;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.mic_off, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Microphone access is required to listen for voice commands.",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return false;
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Microphone Permission Required"),
        content: const Text(
          "Voice Control requires microphone access to recognize your speech commands. Please enable microphone permission in device settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (isListening) {
      await _speech.stop();
      setState(() {
        isListening = false;
      });
      if (recognizedText.isNotEmpty) {
        _processCommand(recognizedText);
      }
      return;
    }

    // 1. Check & request microphone permission
    final hasPerm = await _requestMicrophonePermission();
    if (!hasPerm) return;

    // 2. Ensure speech engine is initialized
    if (!_isSpeechInitialized) {
      await _initSpeechRecognizer();
    }

    if (!_isSpeechInitialized) {
      setState(() {
        errorMessage = "Speech recognition service is not available on this device.";
      });
      return;
    }

    setState(() {
      isListening = true;
      recognizedText = "";
      errorMessage = null;
      lastExecutedAction = null;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              recognizedText = result.recognizedWords;
            });
            if (result.finalResult) {
              setState(() {
                isListening = false;
              });
              _processCommand(result.recognizedWords);
            }
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint("[SpeechToText] listen error: $e");
      if (mounted) {
        setState(() {
          isListening = false;
          errorMessage = "Could not start microphone: $e";
        });
      }
    }
  }

  void _processCommand(String text) {
    if (text.trim().isEmpty) return;

    final action = state.executeVoiceCommand(text);
    setState(() {
      lastExecutedAction = action;
    });

    state.addLog(
      LogType.cmd,
      action != null ? 'VOICE CMD: "$text" -> $action' : 'VOICE UNKNOWN: "$text"',
    );
  }

  void _openVoiceCommandsModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF0F9FF),
                        ),
                        child: const Icon(Icons.record_voice_over, size: 16, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Voice Command Library',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF1F5F9),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCmdRow('“Forward” / “Move forward”', Icons.arrow_upward, const Color(0xFF0284C7), 'F'),
                      _buildCmdRow('“Backward” / “Reverse”', Icons.arrow_downward, const Color(0xFF0284C7), 'B'),
                      _buildCmdRow('“Turn left” / “Left”', Icons.turn_left, const Color(0xFF0284C7), 'L'),
                      _buildCmdRow('“Turn right” / “Right”', Icons.turn_right, const Color(0xFF0284C7), 'R'),
                      _buildCmdRow('“Stop” / “Halt” / “Brake”', Icons.stop_circle, const Color(0xFFE11D48), 'S', isAlert: true),
                      _buildCmdRow('“Turn on lights” / “Light on”', Icons.lightbulb, const Color(0xFFF59E0B), '1'),
                      _buildCmdRow('“Turn off lights” / “Light off”', Icons.lightbulb_outline, const Color(0xFF94A3B8), '0'),
                      _buildCmdRow('“RGB lamp on” / “RGB lights on”', Icons.flare, const Color(0xFF8B5CF6), 'RGB_POWER:1'),
                      _buildCmdRow('“RGB lamp off” / “RGB lights off”', Icons.flare_outlined, const Color(0xFF64748B), 'RGB_POWER:0'),
                      _buildCmdRow('“Horn” / “Honk” / “Beep”', Icons.volume_up, const Color(0xFF10B981), 'H'),
                      _buildCmdRow('“Start dance mode”', Icons.celebration, const Color(0xFF8B5CF6), 'X'),
                      _buildCmdRow('“Fast” / “Full speed”', Icons.speed, const Color(0xFF0284C7), 'SPEED:100'),
                      _buildCmdRow('“Slow” / “Half speed”', Icons.slow_motion_video, const Color(0xFF64748B), 'SPEED:50'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCmdRow(String text, IconData icon, Color iconColor, String code, {bool isAlert = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAlert ? const Color(0xFFFECDD3) : const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isAlert ? const Color(0xFFBE123C) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = state.currentDevice.isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFAF9FA).withOpacity(0.95),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEFEDEE),
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1B1C1D)),
            ),
          ),
        ),
        title: const Text(
          'Voice Control',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 22, color: Color(0xFF334155)),
            onPressed: _openVoiceCommandsModal,
            tooltip: "Voice Commands",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bluetooth Connection Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isConnected ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        size: 16,
                        color: isConnected ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isConnected
                              ? 'Connected: ${state.currentDevice.name}'
                              : 'Bluetooth Disconnected • Connect in Devices',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isConnected ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 'TAP TO SPEAK' Pill
                InkWell(
                  onTap: _toggleListening,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: isListening ? const Color(0xFFFEF2F2) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isListening ? const Color(0xFFFCA5A5) : const Color(0xFFF1F5F9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isListening ? const Color(0xFFEF4444).withOpacity(0.2) : Colors.black.withOpacity(0.04),
                          blurRadius: isListening ? 14 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isListening) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          isListening ? 'LISTENING (TAP TO STOP)...' : 'TAP TO SPEAK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: isListening ? const Color(0xFFEF4444) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Waveform bars
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isListening ? 1.0 : 0.0,
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      final baseScale = (_soundLevel.clamp(0.0, 10.0) / 10.0) * 0.5;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(7, (index) {
                          final heights = [10.0, 18.0, 26.0, 32.0, 26.0, 18.0, 10.0];
                          final h = heights[index] * (0.4 + (_waveController.value * 0.4) + baseScale);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 4,
                            height: h.clamp(6.0, 40.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Large Circular Microphone Button
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isListening ? const Color(0xFF0284C7) : Colors.white,
                      border: Border.all(
                        color: isListening ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
                        width: isListening ? 4 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(isListening ? 0.35 : 0.08),
                          blurRadius: isListening ? 40 : 20,
                          spreadRadius: isListening ? 8 : 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.mic,
                        size: 68,
                        color: isListening ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Speech Output Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'SPEECH TRANSCRIPT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recognizedText.isEmpty
                            ? (isListening ? '“Listening for words...”' : '“Tap microphone and speak”')
                            : '“$recognizedText”',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: recognizedText.isEmpty
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (lastExecutedAction != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Text(
                                'Executed: $lastExecutedAction',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (recognizedText.isNotEmpty && !isListening) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline, size: 14, color: Color(0xFFD97706)),
                              SizedBox(width: 6),
                              Text(
                                'Unrecognized command. Tap (i) for examples.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Quick Tap Chips for testing voice commands without speaking
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildQuickChip("Forward", Icons.arrow_upward),
                    _buildQuickChip("Stop", Icons.stop),
                    _buildQuickChip("Lights On", Icons.lightbulb),
                    _buildQuickChip("Lights Off", Icons.lightbulb_outline),
                    _buildQuickChip("RGB Lamp On", Icons.flare),
                    _buildQuickChip("RGB Lamp Off", Icons.flare_outlined),
                    _buildQuickChip("Dance", Icons.celebration),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: const Color(0xFF0284C7)),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onPressed: () {
        setState(() {
          recognizedText = label;
        });
        _processCommand(label);
      },
    );
  }
}
