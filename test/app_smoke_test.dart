import 'package:flutter_test/flutter_test.dart';
import 'package:adb_helper/main.dart';

void main() {
  testWidgets('ADB Tool app renders shell and device pages', (tester) async {
    await tester.pumpWidget(const AdbHelperApp());

    expect(find.text('Devices'), findsAtLeastNWidgets(1));
    expect(find.text('Terminal'), findsAtLeastNWidgets(1));
  });
}
