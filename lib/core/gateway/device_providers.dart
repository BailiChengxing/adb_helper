import 'dart:io';

import 'package:adb_helper/core/gateway/android_device_gateway.dart';
import 'package:adb_helper/core/gateway/desktop_device_gateway.dart';
import 'package:adb_helper/core/gateway/desktop_operations_gateway.dart';
import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/gateway/fake_file_sync.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final availableDevicesProvider = FutureProvider<List<DeviceRef>>((ref) {
  return ref.watch(deviceGatewayProvider).discover();
});

final selectedFileDeviceProvider = StateProvider<DeviceRef?>((ref) => null);

final _fakeFileSyncProvider = Provider<FileSync>((ref) => FakeFileSync());

final fileSyncProvider = Provider.family<FileSync, SessionSpec>((ref, spec) {
  final gateway = ref.watch(deviceGatewayProvider);
  if (gateway is AndroidDeviceGateway) return gateway.fileSync(spec);
  if (gateway is DesktopDeviceGateway) return gateway.fileSync(spec);
  return ref.watch(_fakeFileSyncProvider).forSession(spec);
});
final fastbootGatewayProvider = Provider<FastbootGateway>((ref) {
  return Platform.isAndroid
      ? UnsupportedFastbootGateway()
      : DesktopFastbootGateway();
});

final sideloadGatewayProvider = Provider<SideloadGateway>((ref) {
  return Platform.isAndroid
      ? UnsupportedSideloadGateway()
      : DesktopSideloadGateway();
});
final deviceToolsGatewayProvider = Provider<DeviceToolsGateway>((ref) {
  return Platform.isAndroid
      ? ShellDeviceToolsGateway(ref.watch(deviceGatewayProvider))
      : DesktopDeviceToolsGateway();
});