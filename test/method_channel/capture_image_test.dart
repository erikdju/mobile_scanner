import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MethodChannelMobileScanner platform;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => platform = MethodChannelMobileScanner());
  tearDown(() {
    messenger.setMockMethodCallHandler(platform.methodChannel, null);
  });

  test('requests a frame and waits for its JPEG bytes', () async {
    final frame = Completer<Uint8List>();
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(platform.methodChannel, (call) {
      calls.add(call);
      return frame.future;
    });

    var completed = false;
    final capture = platform.captureImage().then((bytes) {
      completed = true;
      return bytes;
    });
    await pumpEventQueue();
    expect(completed, isFalse);
    expect(calls.single.method, 'captureImage');
    expect(calls.single.arguments, isNull);

    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    frame.complete(jpeg);
    expect(await capture, orderedEquals(jpeg));
  });

  for (final bytes in [null, Uint8List(0)]) {
    test('rejects an empty response: $bytes', () async {
      messenger.setMockMethodCallHandler(
        platform.methodChannel,
        (_) async => bytes,
      );
      await expectLater(
        platform.captureImage(),
        throwsA(isA<MobileScannerException>()),
      );
    });
  }

  test('preserves capture error details', () async {
    messenger.setMockMethodCallHandler(platform.methodChannel, (_) async {
      throw PlatformException(
        code: 'MOBILE_SCANNER_GENERIC_ERROR',
        message: 'The camera stopped during image capture.',
        details: 'interrupted',
      );
    });

    await expectLater(
      platform.captureImage(),
      throwsA(
        isA<MobileScannerException>()
            .having(
              (e) => e.errorDetails?.message,
              'message',
              'The camera stopped during image capture.',
            )
            .having((e) => e.errorDetails?.details, 'details', 'interrupted'),
      ),
    );
  });
}
