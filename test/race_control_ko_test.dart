import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/race_control_ko.dart';

/// 레이스 컨트롤 번역 규칙. 예시 문장은 전부 2025~2026 아카이브의 실제 메시지.
void main() {
  String? ko(String message) => translateRaceControlMessage(message);

  group('깃발', () {
    test('섹터 깃발', () {
      expect(ko('CLEAR IN TRACK SECTOR 7'), '섹터 7 클리어');
      expect(ko('DOUBLE YELLOW IN TRACK SECTOR 12'), '섹터 12 더블 옐로 플래그');
      expect(ko('YELLOW IN TRACK SECTOR 3'), '섹터 3 옐로 플래그');
    });

    test('블루 플래그는 현지 시각을 버린다', () {
      expect(
        ko('WAVED BLUE FLAG FOR CAR 87 (BEA) TIMED AT 16:07:48'),
        '베어먼(87) 블루 플래그',
      );
    });

    test('흑백기는 사유가 없어도 번역한다', () {
      expect(
        ko('BLACK AND WHITE FLAG FOR CAR 10 (GAS) - TRACK LIMITS'),
        '가슬리(10) 흑백기(경고) — 트랙 리밋',
      );
      expect(ko('BLACK AND WHITE FLAG FOR CAR 44 (HAM)'), '해밀턴(44) 흑백기(경고)');
    });
  });

  group('랩타임 삭제', () {
    test('시간·코너·랩을 모두 담는다', () {
      expect(
        ko('CAR 27 (HUL) TIME 2:09.192 DELETED - TRACK LIMITS AT TURN 9 LAP 5 16:07:52'),
        '휠켄베르크(27) 랩타임 2:09.192 삭제 — 트랙 리밋, 9번 코너 · 5랩',
      );
    });

    test('LAP DELETED 와 피트 꼬리표', () {
      expect(
        ko('CAR 12 (ANT) LAP DELETED - TRACK LIMITS AT TURN 14 LAP 9 20:18:25 (PIT)'),
        '안토넬리(12) 랩 기록 삭제 — 트랙 리밋, 14번 코너 · 9랩 (피트인 랩)',
      );
      expect(
        ko('CAR 16 (LEC) LAP DELETED - TRACK LIMITS AT TURN 20 (NEXT LAP PIT)'),
        '르클레르(16) 랩 기록 삭제 — 트랙 리밋, 20번 코너 (다음 랩 · 피트인)',
      );
    });
  });

  group('사건·페널티', () {
    test('위치 + 다중 차량 + 상태 + 사유', () {
      expect(
        ko('TURN 14 INCIDENT INVOLVING CARS 63 (RUS) AND 22 (TSU) NOTED - IMPEDING'),
        '14번 코너 러셀(63), 츠노다(22) 관련 사건 기록 — 진로 방해',
      );
    });

    test('스튜어드 접두어와 "주 사유 - 세부" 사유', () {
      expect(
        ko(
          'FIA STEWARDS: Q2 INCIDENT INVOLVING CARS 81 (PIA) AND 12 (ANT) WILL BE '
          'INVESTIGATED AFTER THE SESSION - FAILING TO FOLLOW RACE DIRECTORS '
          'INSTRUCTIONS - MAXIMUM DELTA TIME',
        ),
        '[스튜어드] Q2 피아스트리(81), 안토넬리(12) 관련 사건 세션 후 조사 — '
        '레이스 디렉터 지시 불이행 · 최대 델타 타임 초과',
      );
    });

    test('복합 위치와 끝의 현지 시각', () {
      expect(
        ko('LAP 12 TURN 3 INCIDENT INVOLVING CAR 27 (HUL) NOTED - LEAVING THE TRACK AND GAINING AN ADVANTAGE'),
        '12랩 3번 코너 휠켄베르크(27) 관련 사건 기록 — 트랙 이탈로 이득',
      );
      expect(
        ko('TURN 12 INCIDENT INVOLVING CARS 41 (LIN) AND 81 (PIA) NOTED - IMPEDING (14:23:27)'),
        '12번 코너 린드블라드(41), 피아스트리(81) 관련 사건 기록 — 진로 방해',
      );
    });

    test('타임 페널티와 이행 완료', () {
      expect(
        ko('FIA STEWARDS: 10 SECOND TIME PENALTY FOR CAR 44 (HAM) - LEAVING THE TRACK AND GAINING AN ADVANTAGE'),
        '[스튜어드] 해밀턴(44) 10초 타임 페널티 — 트랙 이탈로 이득',
      );
      expect(
        ko('FIA STEWARDS: PENALTY SERVED - 10 SECOND TIME PENALTY FOR CAR 23 (ALB)'),
        '알본(23) 10초 타임 페널티 이행 완료',
      );
    });

    test('정정·갱신 접두어와 대시 공백 오타', () {
      expect(
        ko('CORRECTION: INCIDENT INVOLVING CAR 23 (ALB) NOTED -SAFETY CAR PROCEDURE INFRINGEMENT'),
        '[정정] 알본(23) 관련 사건 기록 — 세이프티카 절차 위반',
      );
    });

    test('미등록 드라이버는 TLA 로 표기', () {
      expect(
        ko('INCIDENT INVOLVING CAR 7 (DOO) NOTED - UNSAFE RELEASE'),
        'DOO(7) 관련 사건 기록 — 위험한 릴리스',
      );
    });
  });

  group('세이프티카·세션 진행', () {
    test('고정 문구', () {
      expect(ko('SAFETY CAR DEPLOYED'), '세이프티카 투입');
      expect(ko('VSC ENDING'), 'VSC 종료 예정');
      expect(ko('GREEN LIGHT - PIT EXIT OPEN'), '피트 출구 개방 (그린 라이트)');
      expect(ko('DRS DISABLED IN ZONE 2'), 'DRS 2구역 사용 불가');
      expect(ko('OVERTAKE ENABLED'), '오버테이크 모드 사용 가능');
    });

    test('재개·시작 시각은 현지 시각으로 표기', () {
      expect(ko('SESSION WILL RESUME AT 14:30'), '세션 재개 예정 (현지 14:30)');
      expect(ko('Q3 WILL START AT 16:52'), 'Q3 시작 예정 (현지 16:52)');
    });

    test('강수 확률 세션명 변형', () {
      expect(ko('RISK OF RAIN FOR F1 RACE IS 100%'), '레이스 강수 확률 100%');
      expect(ko('RISK OF RAIN FOR F1 QUALIFYING SESSION IS 20 %'), '퀄리파잉 강수 확률 20%');
      expect(ko('RISK OF RAIN FOR F1 THIRD PRACTICE SESSION IS 0%'), 'FP3 강수 확률 0%');
    });
  });

  group('원문 폴백', () {
    test('모르는 문형은 null', () {
      expect(ko('THIS IS A TEST MESSAGE FROM RACE CONTROL'), isNull);
      expect(ko('SESSION TEMPERATURES: AIR = 21, TRACK = 35'), isNull);
    });

    test('문형은 맞아도 모르는 사유가 섞이면 null', () {
      expect(
        ko('TURN 4 INCIDENT INVOLVING CAR 44 (HAM) NOTED - SOMETHING NEW'),
        isNull,
      );
    });

    test('F2/F3 서포트 레이스 세션명은 번역하지 않는다', () {
      expect(ko('RISK OF RAIN FOR F2 QUALIFYING IS 10%'), isNull);
    });
  });
}
