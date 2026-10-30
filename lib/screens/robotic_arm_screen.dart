import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class MovementItem {
  final String letter;
  String title;
  String subtitle;
  double angle;
  final bool isFixed;

  MovementItem({
    required this.letter,
    required this.title,
    required this.subtitle,
    this.angle = 90.0,
    this.isFixed = false,
  });
}

class RoboticArmScreen extends StatefulWidget {
  const RoboticArmScreen({super.key});

  @override
  State<RoboticArmScreen> createState() => _RoboticArmScreenState();
}

class _RoboticArmScreenState extends State<RoboticArmScreen> {
  final RobotState state = RobotState();
  final List<String> _availableLetters = 'DEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  late List<MovementItem> _movements;
  DateTime _lastSliderSend = DateTime.now();
  int _lastSentAngle = -1;

  @override
  void initState() {
    super.initState();
    _movements = [
      MovementItem(letter: 'A', title: 'Movement A', subtitle: 'Servo Base / Axis 1', angle: 90, isFixed: true),
      MovementItem(letter: 'B', title: 'Movement B', subtitle: 'Shoulder / Axis 2', angle: 90, isFixed: true),
      MovementItem(letter: 'C', title: 'Movement C', subtitle: 'Elbow / Axis 3', angle: 90, isFixed: true),
    ];
  }

  void _resetAllServos() {
    setState(() {
      for (final m in _movements) {
        m.angle = 90.0;
      }
    });
    state.resetAllArmServos();
    for (final m in _movements) {
      state.sendPayload("${m.letter}90\n");
    }
    state.addLog(LogType.cmd, 'ARM: RESET ALL TO 90°');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All servos centered to 90°'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onAngleChanged(MovementItem item, double val) {
    setState(() {
      item.angle = val;
    });
    final int currentAngle = val.toInt();
    final now = DateTime.now();
    if (now.difference(_lastSliderSend).inMilliseconds > 70 && currentAngle != _lastSentAngle) {
      _lastSliderSend = now;
      _lastSentAngle = currentAngle;
      state.setArmAngle(item.letter, val);
    }
  }

  void _onAngleChangeEnd(MovementItem item, double val) {
    _lastSentAngle = val.toInt();
    state.setArmAngle(item.letter, val);
  }

  void _addMovement() {
    if (_availableLetters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum number of movements reached (A-Z).')),
      );
      return;
    }
    final nextLetter = _availableLetters.removeAt(0);
    setState(() {
      _movements.add(
        MovementItem(
          letter: nextLetter,
          title: 'Movement $nextLetter',
          subtitle: 'Auxiliary Servo / Joint',
          angle: 90,
          isFixed: false,
        ),
      );
    });
    state.addLog(LogType.cmd, 'ARM: ADDED AXIS $nextLetter');
  }

  void _removeMovement(int index) {
    final removed = _movements[index];
    _availableLetters.insert(0, removed.letter);
    _availableLetters.sort();
    setState(() {
      _movements.removeAt(index);
    });
    state.addLog(LogType.cmd, 'ARM: REMOVED AXIS ${removed.letter}');
  }

  void _editMovementName(int index) {
    final item = _movements[index];
    final titleController = TextEditingController(text: item.title);
    final subtitleController = TextEditingController(text: item.subtitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Center(
                child: Text(
                  item.letter,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Edit Movement ${item.letter}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Movement Name",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "e.g. Base Rotation, Gripper Clamp",
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Joint / Subtitle (Optional)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: subtitleController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "e.g. Shoulder / Axis 2",
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newSubtitle = subtitleController.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  item.title = newTitle;
                  if (newSubtitle.isNotEmpty) {
                    item.subtitle = newSubtitle;
                  }
                });
                state.addLog(LogType.cmd, "ARM: RENAMED AXIS ${item.letter} TO '$newTitle'");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Renamed Movement ${item.letter} to '$newTitle'"),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF334155)),
            ),
          ),
        ),
        title: const Text(
          'Robotic Arm Control',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: InkWell(
              onTap: _resetAllServos,
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
              // Sliders List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _movements.length,
                itemBuilder: (context, index) {
                  final item = _movements[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFBAE6FD)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.letter,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => _editMovementName(index),
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 11,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      item.subtitle,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${item.angle.toInt()}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                      const Text(
                                        '°',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!item.isFixed) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _removeMovement(index),
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Slider Row
                        Row(
                          children: [
                            const Text('0°', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94A3B8))),
                            Expanded(
                              child: Slider(
                                value: item.angle,
                                min: 0,
                                max: 180,
                                activeColor: const Color(0xFF0284C7),
                                inactiveColor: const Color(0xFFE2E8F0),
                                onChanged: (val) => _onAngleChanged(item, val),
                                onChangeEnd: (val) => _onAngleChangeEnd(item, val),
                              ),
                            ),
                            const Text('180°', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              // Add Movement Button
              InkWell(
                onTap: _addMovement,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '+ Add Movement',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
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
