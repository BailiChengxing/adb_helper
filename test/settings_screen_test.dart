import 'package:adb_helper/core/gateway/desktop_device_gateway.dart';
import 'package:adb_helper/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens desktop settings and selects a theme', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    router.go('/settings');
    await tester.pumpWidget(AdbHelperApp(gateway: DesktopDeviceGateway()));
    await tester.pumpAndSettle();

    expect(find.text('Platform-tools path'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
  });
}
