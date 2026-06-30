# 포매코 Flutter 앱

포매코 Flutter 앱입니다.

## App Settings

- App display name: `포매코`
- Android package name: `kr.formulamagazine.fmk`
- iOS bundle identifier: `kr.formulamagazine.fmk`
- Android permission: `android.permission.INTERNET` is enabled for live JSON fetches.
- App icon source path: `assets/icon/app_icon.png`
- App icon generation: run `dart run flutter_launcher_icons` only after `assets/icon/app_icon.png` exists.
- App icon colors: black / white / yellow. In-app UI colors stay black / white / red.

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
