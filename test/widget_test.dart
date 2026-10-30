import 'package:flutter_test/flutter_test.dart';
import 'package:ibots_remote_app/core/state/robot_state.dart';
import 'package:ibots_remote_app/main.dart';

void main() {
  testWidgets('iBots Remote App smoke test', (WidgetTester tester) async {
    final state = RobotState();
    state.stopSimulatedTelemetry();

    // Build our app and trigger a frame.
    await tester.pumpWidget(const IBotsRemoteApp());
    await tester.pump();

    // Verify title appears
    expect(find.text('iBots Remote Controller'), findsWidgets);
  });
}
