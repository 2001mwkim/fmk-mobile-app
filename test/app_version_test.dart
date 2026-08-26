import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app_version.dart';

/// 앱 정보 화면의 버전 표기는 pubspec 과 수동 동기화라서, 릴리스마다 pubspec 만
/// 올리고 화면 상수를 잊는 사고가 실제로 있었다(v0.1.0 이 0.1.6 까지 방치됨).
/// 여기서 두 값을 맞춰 둔다.
void main() {
  test('kAppVersion / kAppBuildNumber 는 pubspec.yaml 과 일치한다', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final raw = line.split(':')[1].trim(); // 예: 0.1.6+43
    final parts = raw.split('+');

    expect(
      kAppVersion,
      parts[0],
      reason: 'pubspec version 을 올렸으면 lib/app_version.dart 도 함께 고칠 것',
    );
    expect(
      kAppBuildNumber,
      parts.length > 1 ? parts[1] : '',
      reason: 'pubspec 빌드 번호(+ 뒤)와 kAppBuildNumber 가 다르다',
    );
  });

  test('표기 형식은 스토어와 같은 v0.0.0 (0) 꼴이다', () {
    expect(kAppVersionLabel, 'v$kAppVersion ($kAppBuildNumber)');
    expect(RegExp(r'^v\d+\.\d+\.\d+ \(\d+\)$').hasMatch(kAppVersionLabel), isTrue);
  });
}
