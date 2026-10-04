import 'package:flutter_test/flutter_test.dart';
import 'package:adb_helper/main.dart';
import 'package:adb_helper/core/gateway/fake_device_gateway.dart';

void main() {
  testWidgets('ADB Tool app renders device and main navigation', (
    tester,
  ) async {
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();

    expect(find.text('Devices'), findsAtLeastNWidgets(1));
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.text('About'), findsAtLeastNWidgets(1));
  });
}
