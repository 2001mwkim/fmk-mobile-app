#!/bin/sh
# Xcode Cloud 용 Flutter 준비 스크립트.
#
# Xcode Cloud 는 GitHub 에서 저장소를 새로 클론해 빌드하는데, Flutter 프로젝트는
# `flutter pub get` 이 만들어 주는 산출물(Generated.xcconfig, ephemeral SPM
# 패키지 FlutterGeneratedPluginSwiftPackage, 플러그인 등록부)이 없으면
# xcodebuild 가 "package ... doesn't exist in file system" 으로 실패한다.
# 이 스크립트가 클론 직후(post-clone) Flutter 설치 → pub get → pod install 을
# 수행해 로컬 빌드와 같은 상태를 만든다.
#
# 참고: 릴리스 라이브 URL 은 dart-define 없이도 프로덕션이 기본값이라
# (lib/services/live_session_service.dart) 추가 주입이 필요 없다.
set -e

# 로컬 개발 머신과 동일한 Flutter 버전 고정(pubspec 의 sdk 제약과 호환).
FLUTTER_VERSION=3.44.8

echo "Installing Flutter $FLUTTER_VERSION..."
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter precache --ios

# 저장소 루트는 ios/ci_scripts 의 두 단계 위.
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

# 릴리스 설정으로 Generated.xcconfig 를 확정(FLUTTER_BUILD_MODE=release 등).
flutter build ios --config-only --release

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios
pod install

echo "ci_post_clone done"
