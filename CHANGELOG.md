## 1.0.0
`justsoft/video_thumbnail` 0.5.6을 이어받아 `video_thumbnail_flutter`라는 이름으로 처음 배포합니다. Dart 공개 API(`VideoThumbnail.thumbnailData` / `thumbnailFile`, `ImageFormat`)와 MethodChannel 이름은 원본과 같아, 옮길 때는 패키지 이름과 import 경로만 바꾸면 됩니다.

* **iOS Swift Package Manager 지원**: `ios/video_thumbnail_flutter/Package.swift`를 추가해 CocoaPods 없이 빌드됩니다. Flutter 3.44 플러그인 규격대로 `FlutterFramework` 패키지에 의존하고, WebP 인코딩은 `libwebp-Xcode`(1.5.0 이상)를 씁니다. CocoaPods용 podspec도 같은 소스를 쓰도록 유지합니다. (원본 PR #206 참고)
* **iOS 개인정보 매니페스트**: `PrivacyInfo.xcprivacy`를 SPM·CocoaPods 양쪽에 포함합니다.
* **Android Gradle 최신화**: AGP 4.1 → 9.3.1, Gradle Kotlin DSL(`build.gradle.kts`), `namespace` 선언, compileSdk 33 → 36, Java 17, `jcenter()` 제거.
* **[BREAKING] 실패를 오류 코드가 담긴 `PlatformException`으로 전달**: Android는 어떤 실패든 `MissingPluginException`으로, iOS는 `thumbnailData`가 `null`·`thumbnailFile`이 "IO Error"로만 돌아와 원인을 알 수 없었습니다. 이제 두 플랫폼 모두 `VideoThumbnailErrorCode`(`source_error` / `no_frame` / `encode_error` / `io_error`) 코드와 네이티브 원인 메시지를 담아 던집니다. `null` 반환에 기대던 코드는 `try`/`catch`로 바꿔야 합니다. (원본 #188, #191, #75, #77, #52, #78, #94, #99, #109, #134, #164, #195)
* **iOS 공백·한글 파일명 경로 수정**: `thumbnailFile`이 `%20` 같은 퍼센트 인코딩 경로나 자모 분리형(NFD) 한글 경로를 돌려주던 문제를 고쳤습니다. 호출자가 준 경로 문자열 그대로 파일 경로를 만듭니다. (원본 #107)
* **iOS WebP 메모리 관리 수정**: 소유하지 않은 color space·data provider를 해제해 크래시가 날 수 있던 문제, 프레임 이미지와 libwebp 출력 버퍼를 해제하지 않던 누수를 고쳤습니다.
* **iOS HDR·16비트 프레임 WebP 지원**: 8비트 BGRA가 아닌 프레임(HDR, 16비트·float 성분, 다른 색공간)은 WebP가 `null`이던 문제를 고쳤습니다. 8비트 sRGB로 다시 그린 뒤 인코딩합니다. (원본 #195)
* **`thumbnailPath` 없이 쓰기 실패 수정**: 영상 폴더에 쓸 수 없으면(갤러리·외부 저장소 등) 앱 캐시 폴더에 대신 씁니다. (원본 #96, #144, #133, #59, #43)
* **Android 프레임을 못 읽던 영상 대응**: 가장 가까운 프레임(`OPTION_CLOSEST`)을 못 얻으면 가장 가까운 키프레임(`OPTION_CLOSEST_SYNC`)으로 한 번 더 시도합니다. (원본 #106, #56, #140, #148)
* **Android 리소스 누수 수정**: 영상 파일 스트림을 닫고(원본 #166), 축소 전 원본 비트맵을 해제합니다.
* **Android `timeMs` 넘침 수정**: 약 35분 47초를 넘는 `timeMs`가 `int` 곱셈으로 넘치던 문제를 고쳤습니다.
* **Android 빌드 경고 정리**: 인자 캐스트 경고를 없애고, API 30 이상에서는 deprecated된 `WEBP` 대신 `WEBP_LOSSY`/`WEBP_LOSSLESS`를 씁니다(quality 100이면 무손실, iOS와 같음). (원본 #205)
* **입력 정리**: `quality`가 0-100 밖이면 범위 안으로 자릅니다. URL 영상의 파일 이름은 두 플랫폼 모두 URL 경로의 마지막 부분(퍼센트 디코딩)으로 정하고, 없으면 `thumbnail`을 씁니다.
* **Android 로그에서 영상 URL 제거**: 서명 토큰이 붙은 URL이 logcat에 남지 않도록 실패 로그에는 오류 코드만 남깁니다.
* **[BREAKING] 최소 버전 상향**: Flutter 3.44 / Dart 3.7, iOS 13.0, Android API 24(Flutter 3.50 기본값).
* **Dart**: null safety 이전 문법 정리, `flutter_lints` 적용, `invokeMethod`에 반환 타입 명시.
* **테스트·CI**: MethodChannel 인자·오류 단위 테스트와 예제 앱 통합 테스트(실제 영상으로 형식·크기·경로·오류 코드 확인)를 새로 작성하고, PR마다 format·analyze·test·Android 빌드·iOS SPM 빌드·`pub publish --dry-run`을 실행합니다.
* **예제 앱 재작성**: 최신 Flutter 템플릿, `image_picker` / `path_provider` 최신 버전, SPM 전용 iOS 프로젝트.

## 0.5.6
* Actually add the namespace fix for Android
* Bump to 0.5.6
## 0.5.5
* Thank blissfulsaint(Brandon Lisonbee) for:
 - Add namespace fix for Android
* Bump to 0.5.5
## 0.5.3
* Thanks Ajb Coder for:
  -   Fix: IOException on runtime
  -   Fix: IOException
  -   Added IOException to catch with RuntimeException
  -   Update dart min sdk to 2.16.0
  -   Upgrade the android compileSdkVersion to 33
* Bump to 0.5.3

## 0.5.2
* Revert the IOException change which causes compiling error on new Android Studio
* Bump to 0.5.2

## 0.5.1
* Add IOException for Android (Thanks k1zerX)
* Fix boolean value issue and enlarge the time window (Thanks niketatjombay) 
* Bump to 0.5.1

## 0.5.0

* Make the `thumbnailFile` to save image in the cache folder if the `path` is `null` for not file based video
* Add HTTP headers for not file based video
* Bump to 0.5.0

## 0.4.6

* Thanks for julek-kal, Nailer, nilsreichardt
* fix setDataSource for Android 11
* Fetch closest frame instead of closest keyframe
* Fix typo specify in video_thumbnail.dart
* Change version and bump to 0.4.6

## 0.4.3

* Migrate to flutter embedding v2 for Android ( Thanks wangbo4020 )
* Bump to 0.4.3

## 0.3.3

* Revert the 0.3.2, bump version to 0.3.3

## 0.3.1

* Fix some null safety warnings, bump version to 0.3.1

## 0.3.0

* Add the null safety support ( Thanks leynier41@gmail.com ), bump version to 0.3.0

## 0.2.5+1

* Fix the typo in iOS ( Thanks ztsyyb <1194234257@qq.com> )

## 0.2.5

* Two enhancement

## 0.2.4

* Fix the missing 'platforms' issue

## 0.2.3

* Generate the thumbnails in a background thread for iOS (Thanks for Hafeez Ahmed)

## 0.2.2

* Fix memory leak ( Thanks for Grigori )
* Additional potential memory leak fix

## 0.2.1

* Remove logging out the setDataSource to prevent leaking the video URL
* Accept the file source with the 'file://' prefix
* Give all default values to make it more user friendly

## 0.2.0

* Breaking change: Switch the `maxHeightOrWidth` to `maxHeight` and `maxWidth`

## 0.1.7

* Generate the thumbnail asynchronously on Android. ( Thanks for Tairs Rzajevs )
## 0.1.6

* Add timeMs, use getScaledFrameAtTime to eliminate image scaling if Android API level >= 27
## 0.1.5+1

* Minor updates
## 0.1.5

* Add repository and issue tracker link and bump version to 0.1.5
## 0.1.3+5

* Fix compiler warning
## 0.1.3+4

* Fix "src/dsp/dsp.h" couldn't find issue due to Podfile has "use_frameworks!"
## 0.1.3+3

* Fix the screen shots url issue
## 0.1.3+2

* Add some screen shots
## 0.1.3

* Bump the version
## 0.0.3

* Add test case
## 0.0.2

* Add webp support for iOS
## 0.0.1

* initial release for this flutter plugin.
