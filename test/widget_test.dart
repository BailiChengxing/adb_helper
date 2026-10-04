import 'package:adb_helper/main.dart';
import 'package:adb_helper/core/gateway/fake_device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final locales = <(int, String)>[(1, '设备'), (2, '裝置'), (3, 'Devices')];

  for (final (languageIndex, expectedLabel) in locales) {
    testWidgets('renders $expectedLabel in the selected language', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'language': languageIndex});
      await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
      await tester.pumpAndSettle();
      router.go('/devices');
      await tester.pumpAndSettle();

      expect(find.text(expectedLabel), findsAtLeastNWidgets(1));
      expect(find.text('Pixel 9'), findsOneWidget);
    });
  }

  testWidgets('opens a connected device session in the terminal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Device actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal').last);
    await tester.pumpAndSettle();

    expect(find.text('Pixel 9'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Connected to local shell'), findsOneWidget);
  });

  testWidgets('opens the terminal for the selected device', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Device actions').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Connected to 10.0.0.42:5555'), findsOneWidget);
  });

  testWidgets('connects a previously paired endpoint by IP and port', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '192.168.1.50');
    await tester.enterText(find.byType(TextField).at(1), '5555');
    await tester.tap(find.text('Connect by IP and port'));
    await tester.pumpAndSettle();

    expect(
      find.text('Connected to Wireless device at 192.168.1.50'),
      findsOneWidget,
    );
  });

  testWidgets('opens application management for an ADB device', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Device actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applications').first);
    await tester.pumpAndSettle();

    expect(find.text('com.example.notes'), findsOneWidget);
    await tester.tap(find.text('Install APK'));
    await tester.pumpAndSettle();
    expect(find.text('Install AAB'), findsOneWidget);
    expect(find.text('From this device'), findsOneWidget);
    await tester.tap(find.text('Install AAB'));
    await tester.pumpAndSettle();
    expect(find.text('Install AAB'), findsNothing);
  });

  testWidgets('disables Root and Shizuku choices on desktop', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(
      find.text('Root and Shizuku execution are only available on Android.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(DropdownButton<Transport>));
    await tester.pumpAndSettle();
    final choices = tester
        .widgetList<DropdownMenuItem<Transport>>(
          find.byType(DropdownMenuItem<Transport>),
        )
        .toList();
    expect(
      choices.singleWhere((item) => item.value == Transport.shizuku).enabled,
      isFalse,
    );
    expect(
      choices.singleWhere((item) => item.value == Transport.root).enabled,
      isFalse,
    );
    await tester.tap(find.text('Local shell').last);
    await tester.pumpAndSettle();
  });

  testWidgets('rediscovers devices when returning from a device tool', (
    tester,
  ) async {
    final gateway = _CountingGateway();
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: gateway));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();
    expect(gateway.discoverCount, 1);

    await tester.tap(find.byTooltip('Device actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal').last);
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(gateway.discoverCount, greaterThan(1));
  });

  testWidgets('opens the device file browser', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Device actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files').first);
    await tester.pumpAndSettle();

    expect(find.text('storage'), findsOneWidget);
    expect(find.text('system'), findsOneWidget);
    expect(find.text('System root directory'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Internal storage'), findsOneWidget);
    await tester.tap(find.text('Internal storage').last);
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('shows detailed information for a selected device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Device actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device information').last);
    await tester.pumpAndSettle();

    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Demo device'), findsOneWidget);
    expect(find.text('1080x2400'), findsOneWidget);
  });

  testWidgets('shows the about page from the main navigation', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(AdbHelperApp(gateway: FakeDeviceGateway()));
    await tester.pumpAndSettle();
    router.go('/devices');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('ADB Helper'), findsOneWidget);
    expect(find.text('What you can do'), findsOneWidget);
  });
}

class _CountingGateway extends FakeDeviceGateway {
  int discoverCount = 0;

  @override
  Future<List<DeviceRef>> discover() {
    discoverCount++;
    return super.discover();
  }
}
