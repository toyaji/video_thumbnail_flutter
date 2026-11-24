# video_thumbnail_flutter

[![pub package](https://img.shields.io/pub/v/video_thumbnail_flutter.svg)](https://pub.dev/packages/video_thumbnail_flutter)
[![PR Validation](https://github.com/toyaji/video_thumbnail_flutter/actions/workflows/pr_validation.yml/badge.svg)](https://github.com/toyaji/video_thumbnail_flutter/actions/workflows/pr_validation.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Creates a thumbnail image from a local video file or a video URL on Android and iOS.
It returns the image in memory or saves it as a file, in JPEG, PNG or WebP, with a chosen
size, frame time and quality.

![video-file](https://github.com/toyaji/video_thumbnail_flutter/blob/main/video_file.png?raw=true) ![video-url](https://github.com/toyaji/video_thumbnail_flutter/blob/main/video_url.png?raw=true)

## Why this fork

[justsoft/video_thumbnail](https://github.com/justsoft/video_thumbnail) has had no release since
0.5.6 (May 2025). Its podspec-only iOS plugin and AGP 4 Android build do not work in apps that
build iOS with Swift Package Manager only or use a current Android Gradle Plugin. This package
continues it under a new name with the same Dart API.

| | `video_thumbnail` 0.5.6 | `video_thumbnail_flutter` 1.0 |
|--|--|--|
| iOS dependency manager | CocoaPods only | **Swift Package Manager**, CocoaPods still supported |
| Android build | AGP 4.1, compileSdk 33, `jcenter()` | AGP 9, compileSdk 36, `namespace`, Java 17 |
| Failures | `MissingPluginException` on Android, `null` on iOS | `PlatformException` with an [error code](#errors) on both |
| Paths with spaces or non-ASCII names (iOS) | percent-encoded (`%20`) path returned | the path as given |
| Video folder not writable | write fails | falls back to the app's cache folder |
| WebP of HDR / 16-bit frames (iOS) | `null` | encoded |
| Tests | broken | unit tests and builds in CI on every PR, integration tests with real videos on iOS and Android |

See [CHANGELOG.md](CHANGELOG.md) for the full list and the upstream issues each change closes.

## Requirements

| | Minimum |
|--|--|
| Flutter | 3.44 |
| Dart | 3.7 |
| iOS | 13.0 |
| Android | API 24 |

Flutter 3.44 is the first version whose Swift Package Manager plugins depend on the
`FlutterFramework` package, which this plugin's `Package.swift` uses.

## Installing

```yaml
dependencies:
  video_thumbnail_flutter: ^1.0.0
```

```dart
import 'package:video_thumbnail_flutter/video_thumbnail_flutter.dart';
```

On iOS the plugin is resolved through Swift Package Manager when it is enabled (the default in
current Flutter), and through CocoaPods otherwise. To read videos from URLs on Android, declare the
internet permission in your app's `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

## Migrating from `video_thumbnail`

1. In `pubspec.yaml`, replace `video_thumbnail` with `video_thumbnail_flutter: ^1.0.0`.
2. Replace `package:video_thumbnail/video_thumbnail.dart` with
   `package:video_thumbnail_flutter/video_thumbnail_flutter.dart`.
3. Handle failures as exceptions. `VideoThumbnail`, `ImageFormat` and every parameter are unchanged,
   but a failed call now throws a `PlatformException` on both platforms instead of returning `null`
   on iOS:

```dart
try {
  final bytes = await VideoThumbnail.thumbnailData(video: path);
} on PlatformException catch (e) {
  // e.code is one of VideoThumbnailErrorCode
}
```

## Methods

|function|parameters|returns|
|--|--|--|
|`thumbnailData`|`video`, `headers`, `imageFormat`, `maxHeight`, `maxWidth`, `timeMs`, `quality`|`Future<Uint8List?>`: the encoded image|
|`thumbnailFile`|`video`, `headers`, `thumbnailPath`, `imageFormat`, `maxHeight`, `maxWidth`, `timeMs`, `quality`|`Future<String?>`: the path of the written file|

|parameter|default|description|
|--|--|--|
|`video`|required|A local file path (`/…` or `file://…`) or a URL. A network URL must be properly URL encoded.|
|`headers`|`null`|HTTP headers used when `video` is a URL.|
|`thumbnailPath`|`null`|A folder, or a full file path whose extension matches `imageFormat`. See [Where the file is written](#where-the-file-is-written).|
|`imageFormat`|`ImageFormat.PNG`|`ImageFormat.JPEG`, `ImageFormat.PNG` or `ImageFormat.WEBP`.|
|`maxHeight` / `maxWidth`|`0`|`0` keeps the video resolution. Giving only one keeps the aspect ratio.|
|`timeMs`|`0`|The time of the frame in milliseconds.|
|`quality`|`10`|`0`-`100`; values outside are clamped. Ignored for PNG. For WebP, `100` produces a lossless image (on Android 10 and later).|

### Where the file is written

| `thumbnailPath` | file written to |
|--|--|
| a path ending in the format's extension, e.g. `/tmp/cover.jpg` | exactly that path |
| a folder, e.g. `/tmp` | `/tmp/<video name>.<ext>` |
| omitted, `video` is a local file | next to the video; the app's cache folder if that folder is not writable |
| omitted, `video` is a URL | the app's cache folder |

`<video name>` is the last path segment of the video without its extension, or `thumbnail` when
the path has none (for example `https://host/?id=1`).

The returned path is the plain file path, without percent-encoding.

## Errors

Both methods throw a `PlatformException` when no thumbnail can be made. Its `code` is one of
`VideoThumbnailErrorCode`, and `message` / `details` carry the native cause.

|`VideoThumbnailErrorCode`|code|meaning|
|--|--|--|
|`sourceError`|`source_error`|The video could not be opened: missing file, unreadable URL or unsupported container.|
|`noFrame`|`no_frame`|No frame could be decoded at `timeMs`, or the codec is not supported on the device.|
|`encodeError`|`encode_error`|The frame could not be encoded in `imageFormat`.|
|`ioError`|`io_error`|The thumbnail file could not be written.|

```dart
try {
  final bytes = await VideoThumbnail.thumbnailData(video: path, timeMs: 5000);
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
);
```

## Platform notes

**Android**
* Frames are read with `MediaMetadataRetriever` at the closest frame to `timeMs`. If a video or
  device cannot return that frame, the closest key frame is used instead.
* Giving both `maxWidth` and `maxHeight` scales the frame to fit within them on API 27+, and to
  exactly that size on older versions. A size larger than the video scales it up, unlike iOS.

**iOS**
* Frames are read with `AVAssetImageGenerator`, within 100 ms after `timeMs`. `maxWidth` and
  `maxHeight` only scale down.
* WebP is encoded with [libwebp](https://github.com/SDWebImage/libwebp-Xcode). HDR and other
  non-8-bit frames are converted to 8-bit sRGB first.
* The plugin ships a privacy manifest (`PrivacyInfo.xcprivacy`); it collects no data.

## Example

[`example/`](example) picks a video or takes a URL and shows the thumbnail with the chosen format,
size, time and quality. Its integration tests run the plugin on real videos:

```bash
cd example && flutter test integration_test -d <device-id>
```

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the checks each
pull request must pass.

## License

MIT. Originally written by John Zhong and the
[video_thumbnail contributors](https://github.com/justsoft/video_thumbnail/graphs/contributors).
