class RoboticDevice {
  final String id;
  final String name;
  final String macAddress;
  final String ipAddress;
  final String protocol; // "BLE 5.2", "Bluetooth Classic", "Wi-Fi AP", "MQTT"
  final int rssi;
  final bool isConnected;
  final double batteryVoltage;
  final int pingMs;
  final String deviceType; // "Rover", "Arm", "Cam", "Drone"

  const RoboticDevice({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.ipAddress,
    required this.protocol,
    required this.rssi,
    this.isConnected = false,
    this.batteryVoltage = 8.4,
    this.pingMs = 12,
    this.deviceType = "Rover",
  });

  RoboticDevice copyWith({
    String? id,
    String? name,
    String? macAddress,
    String? ipAddress,
    String? protocol,
    int? rssi,
    bool? isConnected,
    double? batteryVoltage,
    int? pingMs,
    String? deviceType,
  }) {
    return RoboticDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      protocol: protocol ?? this.protocol,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      pingMs: pingMs ?? this.pingMs,
      deviceType: deviceType ?? this.deviceType,
    );
  }
}

enum LogType { system, bluetooth, tx, rx, error, cmd }

class TerminalLog {
  final String timestamp;
  final String message;
  final LogType type;

  TerminalLog({
    required this.timestamp,
    required this.message,
    required this.type,
  });
}

class CodeExampleItem {
  final String title;
  final String category; // "Arduino", "ESP-IDF", "MicroPython", "ROS"
  final String description;
  final String language;
  final String code;

  const CodeExampleItem({
    required this.title,
    required this.category,
    required this.description,
    required this.language,
    required this.code,
  });
}

class FaqItem {
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}
