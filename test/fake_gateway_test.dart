import 'package:adb_helper/core/gateway/fake_device_gateway.dart';
import 'package:adb_helper/core/gateway/fake_file_sync.dart';
import 'package:adb_helper/core/gateway/desktop_device_gateway.dart';
import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/gateway/device_providers.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeDeviceGateway', () {
    test('streams command and output events in order', () async {
      final gateway = FakeDeviceGateway();
      final shell = await gateway.open(const SessionSpec(transport: Transport.local));
      final events = <ShellEvent>[];
      final subscription = shell.events.listen(events.add);
      await Future<void>.delayed(Duration.zero);

      await shell.write('echo hello\n');
      await Future<void>.delayed(Duration.zero);

      expect(events.map((event) => event.data).join(), contains('Connected to local shell'));
      expect(events.map((event) => event.data).join(), contains('\$ echo hello\nhello\n'));
      await subscription.cancel();
      await shell.close();
    });

    test('pairing adds the wireless device to discovery', () async {
      final gateway = FakeDeviceGateway();

      final result = await gateway.pair(
        const PairSpec(host: '192.168.1.20', port: 37123, code: '123456'),
      );
      final devices = await gateway.discover();

      expect(result.ok, isTrue);
      expect(devices.any((device) => device.id == result.serial), isTrue);
    });
  });

  group('FakeFileSync', () {
    test('creates, renames, and deletes a directory entry', () async {
      final sync = FakeFileSync();

      const internalStorage = '/storage/emulated/0';
      await sync.mkdir('$internalStorage/Notes');
      expect((await sync.list(internalStorage)).any((entry) => entry.name == 'Notes'), isTrue);
      await sync.rename('$internalStorage/Notes', '$internalStorage/Archive');
      expect((await sync.list(internalStorage)).any((entry) => entry.name == 'Archive'), isTrue);
      await sync.delete('$internalStorage/Archive');
      expect((await sync.list(internalStorage)).any((entry) => entry.name == 'Archive'), isFalse);
    });
  });

  test('desktop file sessions use the ADB-backed file sync', () {
    final gateway = DesktopDeviceGateway();
    final container = ProviderContainer(
      overrides: [deviceGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    final sync = container.read(
      fileSyncProvider(
        const SessionSpec(
          transport: Transport.usb,
          serial: 'device-serial',
        ),
      ),
    );

    expect(sync, isNot(isA<FakeFileSync>()));
  });
}
