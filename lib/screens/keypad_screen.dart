import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  final RobotState state = RobotState();
  String currentBuffer = "";
  final int maxBufferLength = 16;
  String? toastMessage;
  IconData toastIcon = Icons.info;
  String? lastTransmitted;
  bool instantSend = true;

  void _showToast(String msg, {IconData icon = Icons.info}) {
    setState(() {
      toastMessage = msg;
      toastIcon = icon;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          if (toastMessage == msg) toastMessage = null;
        });
      }
    });
  }

  void _appendKey(String val) {
    if (currentBuffer.length >= maxBufferLength) {
      _showToast('Buffer full (16 bytes maximum)', icon: Icons.warning_amber_rounded);
      return;
    }
    
    HapticFeedback.lightImpact();

    setState(() {
      currentBuffer += val;
      lastTransmitted = val;
    });

    if (instantSend) {
      // Transmit single key command immediately over active link (Wi-Fi or Bluetooth)
      state.sendPayload("$val\n");
      state.addTerminalLog(">>> KEYPAD_TX: '$val'", LogType.tx);
      state.addLog(LogType.cmd, 'KEYPAD: $val');
      
      final bool isDevConnected = state.isConnected || state.wifiService.isConnected;
      if (!isDevConnected) {
        _showToast('Key "$val" queued (Device not connected)', icon: Icons.sensors_off);
      }
    } else {
      state.addLog(LogType.cmd, 'BUFFER: $val');
    }
  }

  void _backspaceDigit() {
    HapticFeedback.selectionClick();
    if (currentBuffer.isNotEmpty) {
      setState(() {
        currentBuffer = currentBuffer.substring(0, currentBuffer.length - 1);
      });
    }
  }

  void _clearDisplay() {
    HapticFeedback.selectionClick();
    if (currentBuffer.isNotEmpty) {
      setState(() {
        currentBuffer = "";
        lastTransmitted = null;
      });
      _showToast('Buffer cleared', icon: Icons.delete_outline);
    }
  }

  void _handleSendPayload() {
    if (currentBuffer.isEmpty) {
      _showToast('Enter digits prior to transmit', icon: Icons.priority_high);
      return;
    }
    
    HapticFeedback.mediumImpact();
    final payload = currentBuffer;
    
    // Transmit accumulated packet payload over active link (Wi-Fi or Bluetooth)
    state.sendPayload("$payload\n");
    state.addTerminalLog(">>> KEYPAD_PACKET: '$payload'", LogType.tx);
    state.addLog(LogType.cmd, 'TX PACKET: $payload');
    
    setState(() {
      lastTransmitted = payload;
      currentBuffer = "";
    });

    final bool isDevConnected = state.isConnected || state.wifiService.isConnected;
    _showToast(
      isDevConnected ? 'Transmitted: $payload' : 'Transmitted (Device not connected)',
      icon: isDevConnected ? Icons.send : Icons.sensors_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final bool isConnected = state.isConnected;
        final bool hasDigits = currentBuffer.isNotEmpty;
        final String displayDigits = hasDigits
            ? currentBuffer.split('').join(' ')
            : '—— —— ——';

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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF1E293B)),
                ),
              ),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Virtual Keypad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Text(
                  'SERIAL COMMAND GATEWAY',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Bluetooth Connection Status Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isConnected ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                    size: 16,
                                    color: isConnected ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isConnected
                                          ? 'Connected: ${state.currentDevice.name}'
                                          : 'Bluetooth Disconnected',
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
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  instantSend = !instantSend;
                                });
                                _showToast(
                                  instantSend ? 'Instant Key TX Enabled' : 'Packet Mode Enabled',
                                  icon: instantSend ? Icons.flash_on : Icons.all_inbox,
                                );
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: instantSend ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: instantSend ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      instantSend ? Icons.flash_on : Icons.all_inbox,
                                      size: 12,
                                      color: instantSend ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      instantSend ? 'Instant TX' : 'Packet Only',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: instantSend ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // MAIN READOUT BUFFER CARD
                      Container(
                        width: double.infinity,
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card Header
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.data_array, size: 16, color: Color(0xFF0284C7)),
                                      SizedBox(width: 6),
                                      Text(
                                        'PAYLOAD BUFFER',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (lastTransmitted != null)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: const Color(0xFF86EFAC)),
                                          ),
                                          child: Text(
                                            'TX: $lastTransmitted',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${currentBuffer.length} / $maxBufferLength B',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        // Value Display Area
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayDigits,
                                  style: TextStyle(
                                    fontFamily: hasDigits ? 'monospace' : null,
                                    fontSize: hasDigits ? 28 : 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: hasDigits ? 2 : 3,
                                    color: hasDigits ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasDigits)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'TX READY',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Display Micro-Actions Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _clearDisplay,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.clear_all, size: 13, color: Color(0xFF64748B)),
                                          SizedBox(width: 4),
                                          Text(
                                            'CLR',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _backspaceDigit,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 28,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Icon(Icons.backspace, size: 14, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // KEYPAD MATRIX GRID (4x4)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      children: [
                        _buildKeypadRow(['1', '2', '3', 'A'], ['.', 'ABC', 'DEF', 'CMD1']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['4', '5', '6', 'B'], ['GHI', 'JKL', 'MNO', 'CMD2']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['7', '8', '9', 'C'], ['PQRS', 'TUV', 'WXYZ', 'CMD3']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['*', '0', '#', 'D'], ['CMD', '+', 'TERM', 'EXEC']),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // OPERATIONAL FOOTER CONTROLS: SEND PACKET
                  InkWell(
                    onTap: _handleSendPayload,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Send Packet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Feedback Micro-Toast
          if (toastMessage != null)
            Positioned(
              bottom: 84,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(toastIcon, size: 16, color: const Color(0xFF5EEAD4)),
                        const SizedBox(width: 8),
                        Text(
                          toastMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Text(
                      'ACK',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildKeypadRow(List<String> keys, List<String> subs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildKeypadButton(keys[index], subs[index]),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadButton(String key, String sub) {
    final bool isActionCol = key == 'A' || key == 'B' || key == 'C' || key == 'D';
    final bool isSpecial = key == '*' || key == '#';

    Color mainColor = const Color(0xFF1E293B);
    if (isActionCol) mainColor = const Color(0xFF0284C7);
    if (isSpecial) mainColor = const Color(0xFF854D0E);

    return InkWell(
      onTap: () => _appendKey(key),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              key,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: mainColor,
                height: 1.1,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
