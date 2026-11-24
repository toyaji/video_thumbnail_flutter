# video_thumbnail_flutter

[![pub package](https://img.shields.io/pub/v/video_thumbnail_flutter.svg)](https://pub.dev/packages/video_thumbnail_flutter)
[![PR Validation](https://github.com/toyaji/video_thumbnail_flutter/actions/workflows/pr_validation.yml/badge.svg)](https://github.com/toyaji/video_thumbnail_flutter/actions/workflows/pr_validation.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Creates a thumbnail image from a local video file or a video URL on Android and iOS.
It returns the image in memory or saves it as a file, in JPEG, PNG or WebP, with a
chosen size, frame time and quality.

![video-file](https://github.com/toyaji/video_thumbnail_flutter/blob/main/video_file.png?raw=true) ![video-url](https://github.com/toyaji/video_thumbnail_flutter/blob/main/video_url.png?raw=true)

## Fork background

This is a maintained fork of [justsoft/video_thumbnail](https://github.com/justsoft/video_thumbnail),
which has had no release since 0.5.6 (May 2025). It is published under a new name and keeps the
**same Dart API**, so migrating only changes the import.

* **Swift Package Manager**: iOS builds with SPM only, no CocoaPods needed. The podspec is kept for
  apps that still use CocoaPods.
* **Current Android Gradle Plugin**: AGP 9, `namespace`, compileSdk 36, Java 17, no `jcenter()`.
* **Tested and checked on every PR**: unit tests, Android build, iOS SPM build and
  `pub publish --dry-run` run in CI.

## Requirements

| | Minimum |
|--|--|
| Flutter | 3.44 |
| Dart | 3.7 |
| iOS | 13.0 |
| Android | API 24 |

## Installing

```yaml
dependencies:
  video_thumbnail_flutter: ^1.0.0
```

```dart
import 'package:video_thumbnail_flutter/video_thumbnail_flutter.dart';
```

### Migrating from `video_thumbnail`

1. Replace `video_thumbnail` with `video_thumbnail_flutter` in `pubspec.yaml`.
2. Replace `package:video_thumbnail/video_thumbnail.dart` with
   `package:video_thumbnail_flutter/video_thumbnail_flutter.dart`.

`VideoThumbnail`, `ImageFormat` and every parameter stay the same. Failures now arrive as a
`PlatformException` with a [code](#errors) on both platforms, instead of `MissingPluginException`
on Android and `null` on iOS.

## Methods

|function|parameters|returns|
|--|--|--|
|`thumbnailData`|`video`, `headers`, `imageFormat`, `maxHeight`, `maxWidth`, `timeMs`, `quality`|`Future<Uint8List?>`: the encoded image|
|`thumbnailFile`|`video`, `headers`, `thumbnailPath`, `imageFormat`, `maxHeight`, `maxWidth`, `timeMs`, `quality`|`Future<String?>`: the path of the saved file|

* `video`: a local file path or a URL. A network URL must be properly URL encoded.
* `headers`: HTTP headers used when `video` is a URL.
* `thumbnailPath`: a folder, or a full file path whose extension matches `imageFormat`.
  When omitted, the file is saved next to the video, or in the app's cache folder when that folder is
  not writable or `video` is a URL.
* `imageFormat`: `ImageFormat.JPEG`, `ImageFormat.PNG` (default) or `ImageFormat.WEBP`.
* `maxHeight` / `maxWidth`: `0` keeps the video resolution; giving only one keeps the aspect ratio.
  On Android, giving both scales the image to exactly that size.
* `timeMs`: the frame time in milliseconds.
* `quality`: `0`-`100`, ignored for PNG.

## Errors

Both methods throw a `PlatformException` when no thumbnail can be made. Its `code` is one of
`VideoThumbnailErrorCode` and `message` / `details` carry the native cause.

|code|meaning|
|--|--|
|`source_error`|The video could not be opened: missing file, unreadable URL or unsupported container.|
|`no_frame`|No frame could be decoded at `timeMs`.|
|`encode_error`|The frame could not be encoded in `imageFormat`.|
|`io_error`|The thumbnail file could not be written.|

```dart
try {
  final bytes = await VideoThumbnail.thumbnailData(video: path);
} on PlatformException catch (e) {
  if (e.code == VideoThumbnailErrorCode.noFrame) {
    // try another timeMs
  }
}
```

## Usage

**Thumbnail in memory from a video file**
```dart
final bytes = await VideoThumbnail.thumbnailData(
  video: videoFile.path,
  imageFormat: ImageFormat.JPEG,
  maxWidth: 128, // the height follows the video's aspect ratio
  quality: 25,
);
```

**Thumbnail file from a video URL**
```dart
final path = await VideoThumbnail.thumbnailFile(
  video: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
  thumbnailPath: (await getTemporaryDirectory()).path,
  imageFormat: ImageFormat.WEBP,
  maxHeight: 64, // the width follows the video's aspect ratio
  quality: 75,
);
```

**Thumbnail file from a video asset**
```dart
final byteData = await rootBundle.load('assets/my_video.mp4');
final tempDir = await getTemporaryDirectory();
final tempVideo = File('${tempDir.path}/assets/my_video.mp4')
  ..createSync(recursive: true)
  ..writeAsBytesSync(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

final path = await VideoThumbnail.thumbnailFile(
  video: tempVideo.path,
  thumbnailPath: tempDir.path,
  imageFormat: ImageFormat.PNG,
  quality: 100,
);
```

On iOS, WebP is encoded with [libwebp](https://github.com/SDWebImage/libwebp-Xcode).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Issues and pull requests are welcome.
