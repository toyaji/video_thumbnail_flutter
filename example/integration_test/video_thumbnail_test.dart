import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail_flutter/video_thumbnail_flutter.dart';

final _chmod = DynamicLibrary.process()
    .lookupFunction<
      Int32 Function(Pointer<Utf8>, Uint16),
      int Function(Pointer<Utf8>, int)
    >('chmod');

void chmod(String path, int mode) {
  final p = path.toNativeUtf8();
  try {
    _chmod(p, mode);
  } finally {
    malloc.free(p);
  }
}

Future<String> copyAsset(String asset, Directory dir, String name) async {
  final data = await rootBundle.load(asset);
  await dir.create(recursive: true);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  return file.path;
}

Future<ui.Image> decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

String fourcc(Uint8List b, int offset) =>
    String.fromCharCodes(b.sublist(offset, offset + 4));

/// RIFF 컨테이너 안의 청크 이름 목록(VP8X·ICCP·VP8L 등).
List<String> webpChunks(Uint8List b) {
  final chunks = <String>[];
  final data = ByteData.sublistView(b);
  var offset = 12;
  while (offset + 8 <= b.length) {
    chunks.add(fourcc(b, offset));
    final size = data.getUint32(offset + 4, Endian.little);
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  return chunks;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String sdr;
  late String hdr;

  setUpAll(() async {
    root = Directory(
      '${(await getTemporaryDirectory()).path}/vt_${DateTime.now().microsecondsSinceEpoch}',
    );
    sdr = await copyAsset(
      'assets/sdr.mp4',
      Directory('${root.path}/샘플 폴더'),
      '테스트 영상 1.mp4',
    );
    hdr = await copyAsset('assets/hdr.mp4', root, 'hdr.mp4');
  });

  tearDownAll(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('thumbnailData', () {
    test('JPEG / PNG / WebP 형식으로 인코딩한다', () async {
      final jpeg = (await VideoThumbnail.thumbnailData(
        video: sdr,
        imageFormat: ImageFormat.JPEG,
        quality: 50,
      ))!;
      final png = (await VideoThumbnail.thumbnailData(
        video: sdr,
        imageFormat: ImageFormat.PNG,
      ))!;
      final webp = (await VideoThumbnail.thumbnailData(
        video: sdr,
        imageFormat: ImageFormat.WEBP,
        quality: 75,
      ))!;

      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(fourcc(webp, 0), 'RIFF');
      expect(fourcc(webp, 8), 'WEBP');
      expect((await decode(webp)).width, 320);
    });

    test('quality 100인 WebP는 무손실(VP8L)이다', () async {
      final webp = (await VideoThumbnail.thumbnailData(
        video: sdr,
        imageFormat: ImageFormat.WEBP,
        quality: 100,
      ))!;
      expect(webpChunks(webp), contains('VP8L'));
    });

    test('maxWidth만 주면 비율을 유지해 줄인다', () async {
      final bytes = (await VideoThumbnail.thumbnailData(
        video: sdr,
        imageFormat: ImageFormat.PNG,
        maxWidth: 64,
      ))!;
      final image = await decode(bytes);
      expect(image.width, 64);
      expect(image.height, 48);
    });

    test(
      '10비트 HEVC(16비트 프레임) 영상도 WebP로 만든다',
      () async {
        final webp = (await VideoThumbnail.thumbnailData(
          video: hdr,
          imageFormat: ImageFormat.WEBP,
          quality: 75,
        ))!;
        expect(fourcc(webp, 8), 'WEBP');
        expect((await decode(webp)).width, 320);
      },
      // 16비트 프레임을 WebP로 못 만들던 문제는 iOS 전용이고, Android 에뮬레이터는 10비트 HEVC를 디코딩하지 못한다.
      skip: Platform.isAndroid,
    );

    test('없는 파일은 source_error PlatformException으로 실패한다', () async {
      await expectLater(
        VideoThumbnail.thumbnailData(video: '${root.path}/missing.mp4'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'source_error',
          ),
        ),
      );
    });
  });

  group('thumbnailFile', () {
    test('공백·한글이 있는 경로를 인코딩하지 않은 그대로 돌려준다', () async {
      final path = (await VideoThumbnail.thumbnailFile(
        video: sdr,
        imageFormat: ImageFormat.JPEG,
      ))!;
      expect(path, '${File(sdr).parent.path}/테스트 영상 1.jpg');
      expect(File(path).existsSync(), isTrue);
    });

    test('thumbnailPath가 폴더면 그 안에, 전체 경로면 그 이름으로 쓴다', () async {
      final dir = Directory('${root.path}/out')..createSync();
      final inDir = (await VideoThumbnail.thumbnailFile(
        video: sdr,
        thumbnailPath: dir.path,
      ))!;
      final named = (await VideoThumbnail.thumbnailFile(
        video: sdr,
        thumbnailPath: '${dir.path}/custom.webp',
        imageFormat: ImageFormat.WEBP,
      ))!;
      expect(inDir, '${dir.path}/테스트 영상 1.png');
      expect(named, '${dir.path}/custom.webp');
      expect(File(inDir).existsSync() && File(named).existsSync(), isTrue);
    });

    test('영상 폴더에 쓸 수 없으면 캐시 폴더에 쓴다', () async {
      final readOnly = Directory('${root.path}/readonly');
      final video = await copyAsset('assets/sdr.mp4', readOnly, 'locked.mp4');
      chmod(readOnly.path, 0x16D); // 0555
      try {
        final path = (await VideoThumbnail.thumbnailFile(
          video: video,
          imageFormat: ImageFormat.JPEG,
        ))!;
        expect(path, isNot(startsWith(readOnly.path)));
        expect(path, endsWith('/locked.jpg'));
        expect(File(path).existsSync(), isTrue);
      } finally {
        chmod(readOnly.path, 0x1ED); // 0755
      }
    });

    test('쓸 수 없는 thumbnailPath는 io_error PlatformException으로 실패한다', () async {
      await expectLater(
        VideoThumbnail.thumbnailFile(
          video: sdr,
          thumbnailPath: '${root.path}/no/such/dir/x.png',
        ),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'io_error'),
        ),
      );
    });
  });
}
