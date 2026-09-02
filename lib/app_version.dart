/// 앱 정보 화면에 표시하는 버전 — pubspec.yaml 의 `version:` 과 **수동 동기화**한다.
/// (package_info_plus 를 쓰면 자동이지만 iOS 는 워치 앱까지 임베드된 Podfile 을
/// 다시 말아야 해서, 이 프로젝트의 다른 수동 동기화 지점들과 같은 방식을 택했다.)
/// 어긋나면 test/app_version_test.dart 가 실패하니 pubspec 만 올리고 테스트를
/// 돌리면 여기서 걸린다 — v0.1.0 이 0.1.6 까지 방치됐던 게 이 테스트를 넣은 이유.
const String kAppVersion = '0.1.9';

/// 스토어·버그 리포트에서 쓰는 빌드 번호(pubspec `version:` 의 `+` 뒤).
const String kAppBuildNumber = '47';

/// 화면 표기 — 스토어 표기와 같은 "0.1.6 (43)" 꼴.
const String kAppVersionLabel = 'v$kAppVersion ($kAppBuildNumber)';
