import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CapturePlatform platform;
  late MobileScannerPlatform previousPlatform;
  late MobileScannerController controller;

  setUp(() {
    previousPlatform = MobileScannerPlatform.instance;
    platform = _CapturePlatform();
    MobileScannerPlatform.instance = platform;
    controller = MobileScannerController(autoStart: false);
  });

  tearDown(() async {
    await controller.dispose();
    MobileScannerPlatform.instance = previousPlatform;
  });

  test('returns bytes without barcode events or returnImage', () async {
    controller.value = controller.value.copyWith(
      isInitialized: true,
      isRunning: true,
    );

    final bytes = await controller.captureImage();

    expect(bytes, orderedEquals(platform.bytes));
    expect(controller.returnImage, isFalse);
    expect(controller.value.isRunning, isTrue);
    expect(platform.captureCalls, 1);
  });

  test('rejects an uninitialized controller', () async {
    await expectLater(
      controller.captureImage(),
      throwsA(
        isA<MobileScannerException>().having(
          (e) => e.errorCode,
          'errorCode',
          MobileScannerErrorCode.controllerUninitialized,
        ),
      ),
    );
    expect(platform.captureCalls, 0);
  });

  test('rejects a stopped or paused controller', () async {
    controller.value = controller.value.copyWith(isInitialized: true);

    await expectLater(
      controller.captureImage(),
      throwsA(isA<MobileScannerException>()),
    );
    expect(platform.captureCalls, 0);
  });

  test('rejects a disposed controller', () async {
    await controller.dispose();

    await expectLater(
      controller.captureImage(),
      throwsA(
        isA<MobileScannerException>().having(
          (e) => e.errorCode,
          'errorCode',
          MobileScannerErrorCode.controllerDisposed,
        ),
      ),
    );
    expect(platform.captureCalls, 0);
  });
}

class _CapturePlatform extends MobileScannerPlatform {
  final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
  int captureCalls = 0;

  @override
  Future<Uint8List> captureImage() async {
    captureCalls++;
    return bytes;
  }

  @override
  Future<void> dispose() async {}
}
