import 'dart:async';
import 'package:flutter/services.dart';

class SensorData {
  final double pitch;
  final double roll;
  final double yaw;

  const SensorData({
    required this.pitch,
    required this.roll,
    required this.yaw,
  });

  @override
  String toString() => 'SensorData(pitch: ${pitch.toStringAsFixed(1)}, roll: ${roll.toStringAsFixed(1)}, yaw: ${yaw.toStringAsFixed(1)})';
}

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;

  SensorService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const MethodChannel _channel = MethodChannel('com.ibots.ibots_remote_app/sensors');

  final _controller = StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _controller.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  Future<void> start() async {
    if (_isListening) return;
    try {
      await _channel.invokeMethod('startSensors');
      _isListening = true;
    } catch (e) {
      // Hardware sensor failure or unsupported
    }
  }

  Future<void> stop() async {
    if (!_isListening) return;
    try {
      await _channel.invokeMethod('stopSensors');
      _isListening = false;
    } catch (e) {
      // ignore
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSensorUpdate') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null) {
        final p = (args['pitch'] as num?)?.toDouble() ?? 0.0;
        final r = (args['roll'] as num?)?.toDouble() ?? 0.0;
        final y = (args['yaw'] as num?)?.toDouble() ?? 0.0;
        _controller.add(SensorData(pitch: p, roll: r, yaw: y));
      }
    }
  }
}
