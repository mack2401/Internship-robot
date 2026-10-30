import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

enum ApHotspotState { disconnected, connecting, connected }

class Esp32CamScreen extends StatefulWidget {
  const Esp32CamScreen({super.key});

  @override
  State<Esp32CamScreen> createState() => _Esp32CamScreenState();
}

class _Esp32CamScreenState extends State<Esp32CamScreen> {
  final RobotState state = RobotState();
  String activeMode = 'AP'; // 'AP' or 'ROUTER'
  ApHotspotState apStatus = ApHotspotState.connected;

  bool isPaused = false;
  bool isRecording = false;
  int recordSeconds = 0;
  Timer? _recordTimer;

  // Resolution feature: 'High', 'Medium', 'Low' (no SVGA or numbers)
  String selectedResolution = 'High';

  final TextEditingController _cameraIpController = TextEditingController(text: '192.168.1.184');

  String _currentTimestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // --- ACCESS POINT HOTSPOT CONNECTION ---
  Future<void> _toggleApConnection() async {
    if (apStatus == ApHotspotState.connecting) return;

    if (apStatus == ApHotspotState.connected) {
      if (isRecording) {
        _stopRecord();
      }
      setState(() {
        apStatus = ApHotspotState.disconnected;
        isPaused = false;
      });
      state.addLog(LogType.cmd, 'CAM: DISCONNECTED FROM HOTSPOT (ESP32-CAM-AP)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected from ESP32-CAM Hotspot'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      setState(() {
        apStatus = ApHotspotState.connecting;
      });
      state.addLog(LogType.cmd, 'CAM: CONNECTING TO HOTSPOT ESP32-CAM-AP (192.168.4.1)...');

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      setState(() {
        apStatus = ApHotspotState.connected;
        isPaused = false;
      });
      state.addLog(LogType.cmd, 'CAM: CONNECTED TO ESP32-CAM-AP (192.168.4.1:81)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected to ESP32-CAM Hotspot (192.168.4.1)'),
          backgroundColor: Color(0xFF065F46),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // --- RECORDING & RESUME LOGIC ---
  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        recordSeconds++;
      });
    });
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
    });

    if (isRecording) {
      if (isPaused) {
        // Paused while recording: stop timer, keep elapsed seconds
        _recordTimer?.cancel();
        state.addLog(LogType.cmd, 'CAM: RECORDING PAUSED AT ${recordSeconds}s');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording paused at ${_formatTime(recordSeconds)}',
            ),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      } else {
        // Resuming: restart timer from existing recordSeconds
        _startRecordTimer();
        state.addLog(LogType.cmd, 'CAM: RECORDING RESUMED (${recordSeconds}s)');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording resumed'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
    } else {
      state.addLog(LogType.cmd, 'CAM: STREAM ${isPaused ? "PAUSED" : "RESUMED"}');
    }
  }

  void _toggleRecord() {
    if (activeMode == 'AP' && apStatus != ApHotspotState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to ESP32-CAM hotspot first')),
      );
      return;
    }

    if (!isRecording) {
      setState(() {
        isRecording = true;
        isPaused = false;
        recordSeconds = 0;
      });
      _startRecordTimer();
      state.addLog(LogType.cmd, 'CAM: STARTED RECORDING');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video recording started'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _stopRecord();
    }
  }

  void _stopRecord() {
    _recordTimer?.cancel();
    final secs = recordSeconds;
    setState(() {
      isRecording = false;
      isPaused = false;
      recordSeconds = 0;
    });
    state.addLog(LogType.cmd, 'CAM: STOPPED RECORDING (${secs}s)');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording saved (${_formatTime(secs)}) to gallery'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _snapPhoto() {
    state.addLog(LogType.cmd, 'CAM: SNAPSHOT CAPTURED');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Screenshot captured to gallery'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // --- RESOLUTION PICKER MODAL (High, Medium, Low) ---
  void _showResolutionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stream Resolution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1C1D),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildResolutionTile('High', Icons.hd, 'Best video clarity & detail', ctx),
              const SizedBox(height: 8),
              _buildResolutionTile('Medium', Icons.tune, 'Balanced performance & smooth stream', ctx),
              const SizedBox(height: 8),
              _buildResolutionTile('Low', Icons.speed, 'Lowest latency & faster response', ctx),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResolutionTile(String label, IconData icon, String subtitle, BuildContext ctx) {
    final isSelected = selectedResolution == label;
    return InkWell(
      onTap: () {
        setState(() {
          selectedResolution = label;
        });
        state.addLog(LogType.cmd, 'CAM: RESOLUTION SET TO $label');
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resolution changed to $label'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 20, color: Color(0xFF0284C7)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _cameraIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStreamActive = activeMode == 'ROUTER' || apStatus == ApHotspotState.connected;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFAF9FA).withOpacity(0.95),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1B1C1D)),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'ESP32 CAM',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B1C1D)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Gallery (0 photos)')),
                );
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E8E9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.photo_library, size: 14, color: Color(0xFF094CB2)),
                    SizedBox(width: 4),
                    Text(
                      'Gallery',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1B1C1D)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 18, color: Color(0xFF1B1C1D)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resetting camera stream...')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF094CB2),
              ),
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. Connection Mode Segmented Controller (Access Point vs Common Router)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => activeMode = 'AP'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: activeMode == 'AP' ? const Color(0xFF094CB2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_tethering,
                                size: 16,
                                color: activeMode == 'AP' ? Colors.white : const Color(0xFF434653),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Access Point',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: activeMode == 'AP' ? Colors.white : const Color(0xFF434653),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => activeMode = 'ROUTER'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: activeMode == 'ROUTER' ? const Color(0xFF094CB2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.router,
                                size: 16,
                                color: activeMode == 'ROUTER' ? Colors.white : const Color(0xFF434653),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Common Router',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: activeMode == 'ROUTER' ? Colors.white : const Color(0xFF434653),
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
              const SizedBox(height: 12),

              // 2. Mode Configuration Card
              if (activeMode == 'AP') ...[
                // CARD 1: Access Point (Hotspot Mode)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.sensors, size: 16, color: Color(0xFF094CB2)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'ESP32 Hotspot Mode',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B1C1D)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9E2FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Direct Connect',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF001946)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'SSID: ESP32-CAM-AP • Default IP: 192.168.4.1',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF5A5F63)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: apStatus == ApHotspotState.connected
                                  ? const Color(0xFFD1FAE5)
                                  : apStatus == ApHotspotState.connecting
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: apStatus == ApHotspotState.connected
                                      ? const Color(0xFF10B981)
                                      : apStatus == ApHotspotState.connecting
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  apStatus == ApHotspotState.connected
                                      ? 'Connected'
                                      : apStatus == ApHotspotState.connecting
                                          ? 'Connecting...'
                                          : 'Offline',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: apStatus == ApHotspotState.connected
                                        ? const Color(0xFF065F46)
                                        : apStatus == ApHotspotState.connecting
                                            ? const Color(0xFF92400E)
                                            : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _toggleApConnection,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: apStatus == ApHotspotState.connected
                                      ? const Color(0xFF094CB2)
                                      : apStatus == ApHotspotState.connecting
                                          ? const Color(0xFF0369A1)
                                          : const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (apStatus == ApHotspotState.connected
                                              ? const Color(0xFF094CB2)
                                              : const Color(0xFF0F172A))
                                          .withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (apStatus == ApHotspotState.connecting) ...[
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Connecting to Hotspot...',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ] else if (apStatus == ApHotspotState.connected) ...[
                                      const Icon(Icons.wifi, size: 16, color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Connected (192.168.4.1)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ] else ...[
                                      const Icon(Icons.wifi_tethering, size: 16, color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Connect to ESP32-CAM Hotspot',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (apStatus == ApHotspotState.connected)
                            InkWell(
                              onTap: _toggleApConnection,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.link_off, size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Disconnect',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: _toggleApConnection,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.refresh, size: 18, color: Color(0xFF475569)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // CARD 2: Common Router (STA Mode)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lan, size: 16, color: Color(0xFF094CB2)),
                              const SizedBox(width: 6),
                              const Text('Common Wi-Fi Network', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDFE3E8),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('STA Mode', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Text('Port :81', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF5A5F63))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Camera IP Address', style: TextStyle(fontSize: 11, color: Color(0xFF5A5F63))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF9FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam, size: 16, color: Color(0xFF5A5F63)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _cameraIpController,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFEDEE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(':81/stream', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF5A5F63))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // 3. Central Camera Viewport (4:3)
              Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF070B12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Viewport Surface Layer
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        ),
                      ),
                      child: !isStreamActive
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.white38),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Hotspot Disconnected',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap "Connect to ESP32-CAM Hotspot" above',
                                    style: TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _toggleApConnection,
                                    icon: const Icon(Icons.wifi, size: 16),
                                    label: const Text('Connect Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            )
                          : isPaused
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isRecording ? Icons.pause_circle_filled : Icons.pause_circle_outline,
                                        size: 48,
                                        color: isRecording ? const Color(0xFFFBBF24) : Colors.white54,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isRecording
                                            ? 'Recording Paused (${_formatTime(recordSeconds)})'
                                            : 'Stream Paused',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0284C7),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: _togglePause,
                                        icon: const Icon(Icons.play_arrow, size: 16),
                                        label: const Text('Resume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                )
                              : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Center Reticle
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.white30, width: 1),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.add, size: 20, color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                    // HUD Top Layer
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Interactive Resolution Selector: High, Medium, Low (No SVGA)
                          GestureDetector(
                            onTap: _showResolutionModal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tune, size: 12, color: Color(0xFFB1C5FF)),
                                  const SizedBox(width: 5),
                                  Text(
                                    selectedResolution,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              // Recording Badge (Active REC or PAUSED REC)
                              if (isRecording) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPaused
                                        ? const Color(0xFF78350F).withOpacity(0.85)
                                        : const Color(0xFF7F1D1D).withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isPaused ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isPaused ? Icons.pause : Icons.circle,
                                        size: 7,
                                        color: isPaused ? const Color(0xFFFBBF24) : const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPaused
                                            ? 'PAUSED ${_formatTime(recordSeconds)}'
                                            : 'REC ${_formatTime(recordSeconds)}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: isStreamActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isStreamActive ? 'Stable' : 'Offline',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: isStreamActive ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isStreamActive ? 'LIVE' : 'STANDBY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isStreamActive ? const Color(0xFFF87171) : Colors.white70,
                                      ),
                                    ),
                                    if (isStreamActive) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        _currentTimestamp(),
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // HUD Bottom Layer
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wifi, size: 12, color: isStreamActive ? const Color(0xFF34D399) : const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  isStreamActive ? '25 FPS • 3.8 Mbps' : '0 FPS • 0 kbps',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.speed, size: 12, color: isStreamActive ? const Color(0xFFFCD34D) : const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  isStreamActive ? '38 ms' : '-- ms',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Stream Controls Row (Pause / Resume, Record, Snap, Full)
              Row(
                children: [
                  // Pause / Resume button
                  Expanded(
                    child: InkWell(
                      onTap: _togglePause,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isPaused ? const Color(0xFFFEF3C7) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPaused ? const Color(0xFFF59E0B) : const Color(0xFFC3C6D5).withOpacity(0.4),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isPaused ? Icons.play_circle : Icons.pause_circle,
                              size: 16,
                              color: isPaused ? const Color(0xFFD97706) : const Color(0xFF094CB2),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPaused ? 'Resume' : 'Pause',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isPaused ? const Color(0xFFB45309) : const Color(0xFF1B1C1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Record button
                  Expanded(
                    child: InkWell(
                      onTap: _toggleRecord,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isRecording ? const Color(0xFFFEE2E2) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRecording ? const Color(0xFFEF4444) : const Color(0xFFC3C6D5).withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isRecording ? _formatTime(recordSeconds) : 'Record',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isRecording ? const Color(0xFFDC2626) : const Color(0xFF1B1C1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Snap button
                  Expanded(
                    child: InkWell(
                      onTap: _snapPhoto,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_camera, size: 16, color: Color(0xFF094CB2)),
                            SizedBox(width: 4),
                            Text('Snap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Full button
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fullscreen preview engaged')),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF094CB2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fullscreen, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Full', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Telemetry Connection Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isStreamActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Connection:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isStreamActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isStreamActive ? 'Stable' : 'Disconnected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isStreamActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.speed, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          isStreamActive ? '38ms' : '--',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF5A5F63)),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: Color(0xFF5A5F63))),
                        const SizedBox(width: 6),
                        Text(
                          isStreamActive ? '0% loss' : 'No signal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isStreamActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 6. Stream Endpoint Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFEDEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.wifi_channel, size: 18, color: Color(0xFF094CB2)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeMode == 'AP' ? 'Access Point Stream (AP)' : 'Router Stream (STA)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B1C1D)),
                            ),
                            Text(
                              activeMode == 'AP'
                                  ? 'http://192.168.4.1:81/stream'
                                  : 'http://${_cameraIpController.text}:81/stream',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF5A5F63)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isStreamActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isStreamActive ? 'LIVE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isStreamActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
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
