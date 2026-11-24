import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_thumbnail_flutter/video_thumbnail_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.justsoft.xyz/video_thumbnail');
  final calls = <MethodCall>[];
  Object? reply;

  setUp(() {
    calls.clear();
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('thumbnailFile', () {
    test('네이티브에 넘기는 인자 키와 값이 원본 플러그인과 같다', () async {
      reply = '/tmp/thumb.jpg';

      final path = await VideoThumbnail.thumbnailFile(
        video: '/videos/a.mp4',
        headers: {'Authorization': 'Bearer x'},
        thumbnailPath: '/tmp',
        imageFormat: ImageFormat.JPEG,
        maxHeight: 120,
        maxWidth: 160,
        timeMs: 1500,
        quality: 45,
      );

      expect(path, '/tmp/thumb.jpg');
      expect(calls.single.method, 'file');
      expect(calls.single.arguments, {
        'video': '/videos/a.mp4',
        'headers': {'Authorization': 'Bearer x'},
        'path': '/tmp',
        'format': 0,
        'maxh': 120,
        'maxw': 160,
        'timeMs': 1500,
        'quality': 45,
      });
    });

    test('기본값은 PNG, 원본 해상도, 0ms, quality 10이다', () async {
      await VideoThumbnail.thumbnailFile(video: '/videos/a.mp4');

      expect(calls.single.arguments, {
        'video': '/videos/a.mp4',
        'headers': null,
        'path': null,
        'format': 1,
        'maxh': 0,
        'maxw': 0,
        'timeMs': 0,
        'quality': 10,
      });
    });
  });

  group('thumbnailData', () {
    test('네이티브가 돌려준 바이트를 그대로 반환한다', () async {
      reply = Uint8List.fromList([1, 2, 3]);

      final data = await VideoThumbnail.thumbnailData(
        video: 'https://example.com/a.mp4',
        imageFormat: ImageFormat.WEBP,
        maxWidth: 128,
        quality: 75,
      );

      expect(data, Uint8List.fromList([1, 2, 3]));
      expect(calls.single.method, 'data');
      expect(calls.single.arguments, {
        'video': 'https://example.com/a.mp4',
        'headers': null,
        'format': 2,
        'maxh': 0,
        'maxw': 128,
        'timeMs': 0,
        'quality': 75,
      });
    });

    test('네이티브가 null을 돌려주면 null을 반환한다', () async {
      final data = await VideoThumbnail.thumbnailData(video: '/videos/a.mp4');

      expect(data, isNull);
    });
  });

  test('네이티브 실패는 오류 코드를 담은 PlatformException으로 전달된다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: VideoThumbnailErrorCode.noFrame,
            message: 'The video has no frame at 0 ms',
          );
        });

    await expectLater(
      VideoThumbnail.thumbnailData(video: '/videos/a.mp4'),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          VideoThumbnailErrorCode.noFrame,
        ),
      ),
    );
  });

  test('오류 코드 값은 네이티브(Android·iOS)와 같아야 한다', () {
    expect(VideoThumbnailErrorCode.sourceError, 'source_error');
    expect(VideoThumbnailErrorCode.noFrame, 'no_frame');
    expect(VideoThumbnailErrorCode.encodeError, 'encode_error');
    expect(VideoThumbnailErrorCode.ioError, 'io_error');
  });

  test('ImageFormat 순서는 네이티브 format 값(0/1/2)과 일치해야 한다', () {
    expect(ImageFormat.values, [
      ImageFormat.JPEG,
      ImageFormat.PNG,
      ImageFormat.WEBP,
    ]);
  });
}
