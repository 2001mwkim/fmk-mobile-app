import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/screens/standings_screen.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> driverRow(int position, String nameKo, num points) => {
    'position': position,
    'driverKo': nameKo,
    'driverEn': 'Driver $position',
    'teamKo': '팀$position',
    'teamEn': 'Team $position',
    'points': points,
  };

  Map<String, dynamic> teamRow(int position, String teamKo, num points) => {
    'position': position,
    'teamKo': teamKo,
    'teamEn': 'Team $position',
    'points': points,
  };

  Map<String, dynamic> validBody({num p1Points = 179}) => {
    'generatedAt': '2026-07-10T02:00:00.000Z',
    'season': 2026,
    'f1dbTag': 'v2026.9.1',
    'driverStandings': [
      driverRow(1, '키미 안토넬리', p1Points),
      for (var i = 2; i <= 12; i++) driverRow(i, '드라이버$i', 100 - i),
    ],
    'constructorStandings': [
      teamRow(1, '메르세데스', 262),
      for (var i = 2; i <= 6; i++) teamRow(i, '컨스트럭터$i', 50 - i),
    ],
  };

  http.Response jsonResponse(Object data) => http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('정상 응답을 파싱하고 /api/standings 를 호출한다', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return jsonResponse(validBody());
    });

    final snapshot = await HttpStandingsRepository(
      baseUrl: 'https://api.example.com',
      client: client,
    ).fetchLatest();

    expect(requested.path, '/api/standings');
    expect(snapshot, isNotNull);
    expect(snapshot!.driverStandings.first.driverKo, '키미 안토넬리');
    expect(snapshot.driverStandings.first.points, 179);
    expect(snapshot.constructorStandings.first.teamKo, '메르세데스');
  });

  test('깨진 항목은 건너뛰고, 그리드 규모 미만이면 null(정적 폴백 신호)', () {
    // 깨진 항목 1개가 섞여도 나머지로 파싱된다
    final body = validBody();
    (body['driverStandings'] as List).add({'position': 'bad'});
    final ok = parseStandingsJson(jsonEncode(body));
    expect(ok, isNotNull);
    expect(ok!.driverStandings.length, 12);

    // 드라이버 10명 미만(불완전 응답) → null
    final tooFew = {
      ...validBody(),
      'driverStandings': [driverRow(1, '한 명', 10)],
    };
    expect(parseStandingsJson(jsonEncode(tooFew)), isNull);

    // 빈 응답(서버 수집 전) → null
    final empty = {
      ...validBody(),
      'driverStandings': <Object>[],
      'constructorStandings': <Object>[],
    };
    expect(parseStandingsJson(jsonEncode(empty)), isNull);
  });

  test('네트워크 실패/HTTP 오류/비정상 JSON 이면 null 을 돌려준다', () async {
    Future<StandingsSnapshot?> fetchWith(MockClient client) =>
        HttpStandingsRepository(
          baseUrl: 'https://api.example.com',
          client: client,
        ).fetchLatest();

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

  testWidgets('서버 순위가 오면 정적 데이터 대신 최신 값을 표시한다', (tester) async {
    final repository = _FakeStandingsRepository(
      parseStandingsJson(jsonEncode(validBody())),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: StandingsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('키미 안토넬리'), findsOneWidget);
    expect(find.text('179'), findsOneWidget); // 서버 값(정적 데이터는 156)
    expect(find.text('156'), findsNothing);
  });

  testWidgets('서버 실패(null) 시 번들된 정적 순위를 그대로 보여준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: StandingsScreen(repository: _FakeStandingsRepository(null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('키미 안토넬리'), findsOneWidget);
    expect(find.text('156'), findsOneWidget); // 정적 데이터 유지
  });
}

class _FakeStandingsRepository implements StandingsRepository {
  _FakeStandingsRepository(this.snapshot);

  final StandingsSnapshot? snapshot;

  @override
  Future<StandingsSnapshot?> fetchLatest() async => snapshot;
}
