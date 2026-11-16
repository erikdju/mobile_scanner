@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/web/mobile_scanner_web.dart';
import 'package:web/web.dart' as web;

import 'utils/media_stream_test_utils.dart';

void main() {
  late GetUserMediaStub media;
  late DetectingBarcodeDetectorStub detector;
  late PlayRecorder recorder;
  late MobileScannerWeb plugin;

  setUp(() async {
    web.window.localStorage.clear();
    media = GetUserMediaStub()..resolve();
    detector = DetectingBarcodeDetectorStub(returnNoBarcodes: true);
    recorder = PlayRecorder();
    plugin =
        MobileScannerWeb()
          ..setWebBarcodeReader(WebBarcodeReader.barcodeDetector);
    await plugin.start(testStartOptions);
  });

  tearDown(() async {
    await plugin.dispose();
    recorder.restore();
    detector.restore();
    media.restore();
  });

  test('waits for the requested frame and returns a decodable JPEG', () async {
    final video = recorder.played.single;
    JSFunction? nextFrame;
    (video as JSObject)['requestVideoFrameCallback'] =
        ((JSFunction callback) {
          nextFrame = callback;
          return 1;
        }).toJS;

    var completed = false;
    final capture = plugin.captureImage().then((bytes) {
      completed = true;
      return bytes;
    });
    await pumpEventQueue();
    expect(completed, isFalse);
    expect(nextFrame, isNotNull);

    nextFrame!.callAsFunction(video, 0.toJS, JSObject());
    final bytes = await capture;
    expect(bytes.take(2), [0xff, 0xd8]);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 32);
    expect(frame.image.height, 32);
    frame.image.dispose();
    codec.dispose();
    expect(allLive(video.srcObject! as web.MediaStream), isTrue);
  });

  test('rejects concurrent capture and cancels when stopped', () async {
    final video = recorder.played.single;
    (video as JSObject)['requestVideoFrameCallback'] =
        ((JSFunction callback) => 1).toJS;
    final capture = plugin.captureImage();
    await expectLater(
      plugin.captureImage(),
      throwsA(isA<MobileScannerException>()),
    );
    final failure = expectLater(
      capture,
      throwsA(isA<MobileScannerException>()),
    );
    await plugin.stop();
    await failure;
  });

  test('rejects capture while paused', () async {
    await plugin.pause();
    await expectLater(
      plugin.captureImage(),
      throwsA(isA<MobileScannerException>()),
    );
  });

  test('capture works again after resuming the camera', () async {
    await plugin.pause();
    await plugin.start(testStartOptions);

    final video = recorder.played.last;
    JSFunction? nextFrame;
    (video as JSObject)['requestVideoFrameCallback'] =
        ((JSFunction callback) {
          nextFrame = callback;
          return 1;
        }).toJS;
    final capture = plugin.captureImage();
    nextFrame!.callAsFunction(video, 0.toJS, JSObject());
    expect((await capture).take(2), [0xff, 0xd8]);
    expect(media.callCount, 1);
  });

  test('times out when the video stops delivering frames', () async {
    final video = recorder.played.single;
    (video as JSObject)['requestVideoFrameCallback'] =
        ((JSFunction callback) => 1).toJS;
    await expectLater(
      plugin.captureImage(),
      throwsA(
        isA<MobileScannerException>().having(
          (e) => e.errorDetails?.message,
          'message',
          'Image capture timed out.',
        ),
      ),
    );
  });
}
