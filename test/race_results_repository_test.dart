import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/race_results.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/models/race.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/services/race_results_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> resultRow(int position, String driverKo, num points) => {
    'position': position,
    'positionLabel': '$position',
    'driverNumber': position,
    'driverCode': 'D$position',
    'driverKo': driverKo,
    'driverEn': 'Driver $position',
    'teamKo': '팀$position',
    'teamEn': 'Team $position',
    'points': points,
    'time': position == 1 ? '1:27:11.335' : null,
    'gap': position == 1 ? null : '+$position.0',
    'timeOrStatus': position == 1 ? '1:27:11.335' : '+$position.0',
  };

  Map<String, dynamic> validBody(String raceId, {String status = 'official'}) => {
    'generatedAt': '2026-07-10T04:00:00.000Z',
    'season': 2026,
    'f1dbTag': 'v2026.9.1',
    'races': [
      {
        'raceId': raceId,
        'round': 9,
        'grandPrixName': 'British Grand Prix',
        'raceName': 'FORMULA 1 BRITISH GRAND PRIX 2026',
        'status': status,
        'results': [
          resultRow(1, '샤를 르클레르', 25),
          for (var i = 2; i <= 12; i++) resultRow(i, '드라이버$i', 30 - i),
        ],
      },
    ],
  };

  http.Response jsonResponse(Object data) => http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('정상 응답을 파싱하고 /api/race-results?season&raceId 를 호출한다', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return jsonResponse(validBody('great-britain-2026'));
    });

    final data = await HttpRaceResultsRepository(
      baseUrl: 'https://api.example.com',
      client: client,
    ).fetchResult(raceId: 'great-britain-2026');

    expect(requested.path, '/api/race-results');
    expect(requested.queryParameters['season'], '2026');
    expect(requested.queryParameters['raceId'], 'great-britain-2026');
    expect(data, isNotNull);
    expect(data!.isOfficial, isTrue);
    expect(data.entries.length, 12);
    expect(data.entries.first.driverKo, '샤를 르클레르');
    expect(data.entries.first.time, '1:27:11.335');
  });

  test('잠정 결과 status / 깨진 행 skip / 불완전 응답(10행 미만) 거부', () {
    // provisional 상태 전달
    final provisional = parseRaceResultJson(
      jsonEncode(validBody('gb', status: 'provisional')),
      raceId: 'gb',
    );
    expect(provisional!.isOfficial, isFalse);

    // 깨진 행이 섞여도 나머지로 파싱
    final body = validBody('gb');
    ((body['races'] as List).first['results'] as List).add({'position': 'bad'});
    final ok = parseRaceResultJson(jsonEncode(body), raceId: 'gb');
    expect(ok!.entries.length, 12);

    // 10행 미만 → 불완전 응답으로 null
    final tooFew = validBody('gb');
    (tooFew['races'] as List).first['results'] = [resultRow(1, '한 명', 25)];
    expect(parseRaceResultJson(jsonEncode(tooFew), raceId: 'gb'), isNull);

    // 요청한 raceId 가 응답에 없으면 null (미개최 라운드)
    expect(
      parseRaceResultJson(jsonEncode(validBody('other-race')), raceId: 'gb'),
      isNull,
    );
  });

  test('네트워크 실패/HTTP 오류/비정상 JSON 이면 null (크래시 없음)', () async {
    Future<RaceResultData?> fetchWith(MockClient client) =>
        HttpRaceResultsRepository(
          baseUrl: 'https://api.example.com',
          client: client,
        ).fetchResult(raceId: 'gb');

    expect(
      await fetchWith(MockClient((_) async => throw http.ClientException('down'))),
      isNull,
    );
    expect(
      await fetchWith(MockClient((_) async => http.Response('oops', 500))),
      isNull,
    );
    expect(
      await fetchWith(MockClient((_) async => http.Response('not json', 200))),
      isNull,
    );
  });

  // ---- 상세 화면 위젯 테스트 ----

  // 종료됐지만 번들 정적 결과가 없는 레이스(현재 "준비 중"으로 보이는 케이스).
  Race endedRaceWithoutStaticResults() => races.firstWhere(
    (r) =>
        getRaceStatus(r) == RaceStatus.ended &&
        !r.isCancelled &&
        getRaceResults(r.id) == null,
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    Race race,
    RaceResultsRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: RaceDetailScreen(race: race, resultsRepository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('서버 결과가 오면 준비 중 카드 대신 순위와 공식 결과 라벨을 표시한다', (
    tester,
  ) async {
    final race = endedRaceWithoutStaticResults();
    final data = parseRaceResultJson(
      jsonEncode(validBody(race.id)),
      raceId: race.id,
    );

    await pumpDetail(tester, race, _FakeRaceResultsRepository(data));

    expect(find.text('결과 데이터 준비 중'), findsNothing);
    expect(find.text('샤를 르클레르'), findsOneWidget); // P1 (상단 3명 강조 영역)
    expect(find.text('공식 결과'), findsOneWidget);
    expect(find.text('4위 이하 순위 보기'), findsOneWidget); // 확장으로 전체 제공
  });

  testWidgets('결과가 없으면(null) 기존 준비 중 카드를 유지한다', (tester) async {
    final race = endedRaceWithoutStaticResults();

    await pumpDetail(tester, race, _FakeRaceResultsRepository(null));

    expect(find.text('결과 데이터 준비 중'), findsOneWidget);
    expect(find.text('공식 결과'), findsNothing);
  });

  testWidgets('저장소가 예외를 던져도 앱이 깨지지 않고 준비 중 카드를 유지한다', (
    tester,
  ) async {
    final race = endedRaceWithoutStaticResults();

    await pumpDetail(tester, race, _ThrowingRaceResultsRepository());

    expect(find.text('결과 데이터 준비 중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRaceResultsRepository implements RaceResultsRepository {
  _FakeRaceResultsRepository(this.data);

  final RaceResultData? data;

  @override
  Future<RaceResultData?> fetchResult({
    required String raceId,
    int season = 2026,
  }) async => data;
}

class _ThrowingRaceResultsRepository implements RaceResultsRepository {
  @override
  Future<RaceResultData?> fetchResult({
    required String raceId,
    int season = 2026,
  }) async => throw Exception('boom');
}
