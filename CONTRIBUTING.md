# CONTRIBUTING

`video_thumbnail_flutter`는 관리가 멈춘 [justsoft/video_thumbnail](https://github.com/justsoft/video_thumbnail)을 이어받아 유지하는 패키지입니다. 이슈·PR 모두 환영합니다.

## 원칙

- **공개 API는 원본과 같게 유지합니다.** `VideoThumbnail.thumbnailData` / `thumbnailFile`, `ImageFormat`, 인자 이름과 기본값, MethodChannel 이름(`plugins.justsoft.xyz/video_thumbnail`)을 바꾸는 변경은 메이저 버전에서만 합니다.
- **iOS는 Swift Package Manager가 기준입니다.** `Package.swift`와 podspec이 같은 소스(`ios/video_thumbnail_flutter/Sources/video_thumbnail_flutter/`)를 씁니다. 파일을 추가·이동하면 두 쪽 모두에서 빌드되는지 확인합니다.
- **최소 변경**: 고치려는 것과 무관한 포맷·이름 변경을 섞지 않습니다.
- **lint를 끄지 않습니다.** `ignore_for_file`은 CI에서 막습니다.
- Flutter·플랫폼 SDK에서 deprecated된 API는 새로 쓰지 않습니다.

## 로컬 검증

PR 전에 아래를 통과시킵니다. CI(`.github/workflows/pr_validation.yml`)도 같은 것을 실행합니다.

```bash
dart format --output=none --set-exit-if-changed lib test example/lib example/test example/integration_test
```

```bash
flutter analyze && flutter test
```

```bash
cd example && flutter analyze && flutter test
```

```bash
cd example && flutter build apk --release
```

iOS SPM 빌드(예제 앱에는 `Podfile`이 없어야 합니다):

```bash
cd example && flutter build ios --no-codesign
```

## 테스트

네이티브 코드를 바꿨으면 시뮬레이터·에뮬레이터에서 예제 앱 통합 테스트를 돌립니다. 실제 영상(`example/assets/`)으로 형식·크기·경로·오류 코드를 확인합니다.

```bash
cd example && flutter test integration_test -d <device-id>
```

- 버그 수정·기능 추가에는 `test/`의 단위 테스트를 함께 넣습니다.
- Dart↔네이티브 인자 계약(키 이름, `ImageFormat` 순서 = 네이티브 `format` 값)은 `test/video_thumbnail_flutter_test.dart`가 지킵니다. 바꾸면 Android·iOS 네이티브 코드도 함께 바꿉니다.

## 릴리스

1. `pubspec.yaml`의 `version`과 `ios/video_thumbnail_flutter.podspec`의 `s.version`을 올립니다.
2. `CHANGELOG.md` 맨 위에 새 버전 항목을 씁니다.
3. `flutter pub publish --dry-run`이 경고 없이 통과하는지 확인한 뒤 배포합니다.
