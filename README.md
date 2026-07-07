# 비아 포뮬러 (Via Formula) Flutter 앱

Formula Magazine Korea가 운영하는 F1 팬 앱 "비아 포뮬러"입니다.

- 스토어명 후보: `비아 포뮬러 - 일정·라이브·직관`
- 운영 브랜드: `Formula Magazine Korea` (포뮬러 매거진 코리아)

## App Settings

- App display name: `비아 포뮬러`
- Android package name: `kr.formulamagazine.fmk`
- iOS bundle identifier: `kr.formulamagazine.fmk`
- Android permission: `android.permission.INTERNET` is enabled for live JSON fetches.
- App icon source path: `assets/icon/app_icon.png`
- App icon generation: run `dart run flutter_launcher_icons` only after `assets/icon/app_icon.png` exists.
- App icon colors: black / white / yellow. In-app UI colors stay black / white / red.

## Android Release Signing (Play 업로드)

release 빌드는 `android/key.properties`에서 업로드 키 정보를 읽는다.
이 파일과 keystore(`*.jks`)는 **gitignore 대상이며 절대 커밋하지 않는다.**
새 머신에서는 아래 형식으로 직접 만든다:

```properties
storePassword=<키스토어 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=upload
storeFile=<upload-keystore.jks 절대 경로>
```

- 빌드(난독화 포함 권장):
  `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define=LIVE_JSON_URL=...`
  (`build/symbols`는 크래시 스택 복원용 심볼 — 릴리즈별로 보관)
- 산출물: `build/app/outputs/bundle/release/app-release.aab`
- key.properties가 없으면 release 빌드는 명확한 에러로 실패한다(debug 빌드는 영향 없음).

## Android Home Widget

- Package: `home_widget`
- Provider: `kr.formulamagazine.fmk.FmkHomeWidgetProvider`
- Layouts: `android/app/src/main/res/layout/widget_fmk_default.xml`, `android/app/src/main/res/layout/widget_fmk_live.xml`
- Data bridge: `lib/services/fmk_home_widget_bridge.dart`
- Display: default Grand Prix session list or live lap/Top 3 state
- iOS WidgetKit is tracked as a follow-up in `docs/android-home-widget.md`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
