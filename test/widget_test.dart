import 'package:adb_helper/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final locales = <(int, String)>[
    (1, '设备'),
    (2, '裝置'),
    (3, 'Devices'),
  ];

  for (final (languageIndex, expectedLabel) in locales) {
    testWidgets('renders $expectedLabel in the selected language', (tester) async {
      SharedPreferences.setMockInitialValues({'language': languageIndex});
      await tester.pumpWidget(const AdbHelperApp());
      await tester.pumpAndSettle();

      expect(find.text(expectedLabel), findsAtLeastNWidgets(1));
      expect(find.text('Pixel 9'), findsOneWidget);
    });
  }

  testWidgets('opens a connected device session in the terminal', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 3});
    await tester.pumpWidget(const AdbHelperApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect').first);
    await tester.pumpAndSettle();

    expect(find.text('Terminal'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Connected to local shell'), findsOneWidget);
  });
}
