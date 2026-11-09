import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/models/race_poll.dart';
import 'package:fmk_app/models/standing.dart';
import 'package:fmk_app/services/polls_repository.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:fmk_app/widgets/race_polls_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 순위 주입용 — 네트워크 없이 고정 스냅샷을 돌려준다.
class _FakeStandingsRepository implements StandingsRepository {
  const _FakeStandingsRepository(this.snapshot);
  final StandingsSnapshot? snapshot;
  @override
  Future<StandingsSnapshot?> fetchLatest() async => snapshot;
}

Map<String, dynamic> _poll({
  bool winnerOpen = true,
  Map<String, int> winnerCounts = const {'VER': 6, 'NOR': 3, 'LEC': 1},
  bool ratingOpen = false,
}) => {
  'raceId': 'brazil-2026',
  'generatedAt': '2026-11-02T00:00:00Z',
  'winner': {
    'opensAt': null,
    'closesAt': '2026-11-08T17:00:00Z',
    'open': winnerOpen,
    'total': winnerCounts.values.fold<int>(0, (a, b) => a + b),
    'counts': winnerCounts,
  },
  'pole': {
    'opensAt': null,
    'closesAt': '2026-11-07T18:00:00Z',
    'open': false,
    'total': 0,
    'counts': <String, int>{},
  },
  'rating': {
    'opensAt': '2026-11-08T18:30:00Z',
    'closesAt': '2026-11-15T17:00:00Z',
    'open': ratingOpen,
    'total': ratingOpen ? 2 : 0,
    'average': ratingOpen ? 4.5 : null,
    'histogram': ratingOpen ? [0, 0, 0, 1, 1] : [0, 0, 0, 0, 0],
  },
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PollsRepository.clearCache();
  });

  test('UUID v4 형식으로 만들고 저장해 재사용한다', () async {
    final id = generateUuidV4(Random(1));
    expect(isUuidV4(id), isTrue);
    expect(isUuidV4('not-a-uuid'), isFalse);
    final first = await PollsRepository.deviceId();
    expect(await PollsRepository.deviceId(), first);
  });

  test('집계를 읽고 득표율 상위를 계산한다', () {
    final poll = RacePoll.tryParse(jsonEncode(_poll()))!;
    expect(poll.winner.open, isTrue);
    expect(poll.winner.top(2), [('VER', 0.6), ('NOR', 0.3)]);
    expect(poll.pole.top(3), isEmpty);
    expect(poll.rating.histogram, hasLength(5));
    // POST 응답처럼 {ok, poll} 로 감싸도 읽는다.
    expect(
      RacePoll.tryParse(jsonEncode({'ok': true, 'poll': _poll()}))!.raceId,
      'brazil-2026',
    );
  });

  test('live.json 과 같은 호스트에서만 투표를 켠다', () {
    expect(
      pollsBaseUrlFor('https://live.formulamagazine.kr/live.json'),
      'https://live.formulamagazine.kr',
    );
    expect(pollsBaseUrlFor('https://www.formulamagazine.kr/api/live'), isNull);
  });

  test('투표는 deviceId 를 담아 보내고, 409 는 마감으로 알린다', () async {
    Map<String, dynamic>? sent;
    var status = 200;
    final repository = PollsRepository(
      baseUrl: 'https://live.example',
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'ok': status == 200, 'poll': _poll()}),
          status,
        );
      }),
    );
    final ok = await repository.vote(
      raceId: 'brazil-2026',
      kind: PollKind.winner,
      value: 'VER',
    );
    expect(ok.poll, isNotNull);
    expect(sent!['kind'], 'winner');
    expect(isUuidV4(sent!['deviceId'] as String), isTrue);
    expect(await repository.myVote('brazil-2026', PollKind.winner), 'VER');

    status = 409;
    final closed = await repository.vote(
      raceId: 'brazil-2026',
      kind: PollKind.winner,
      value: 'NOR',
    );
    expect(closed.error, VoteError.closed);
  });

  testWidgets('예측 분포를 보여주고 고르면 내 예측으로 표시한다', (tester) async {
    // 선택기 그리드 전체가 보이도록 세로로 긴 화면.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = PollsRepository(
      baseUrl: 'https://live.example',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'poll': _poll(winnerCounts: {'VER': 6, 'NOR': 4, 'LEC': 1}),
            }),
            200,
          );
        }
        return http.Response(jsonEncode(_poll()), 200);
      }),
    );
    final race = races.firstWhere((r) => !r.isCancelled);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RacePollsCard(race: race, repository: repository),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('팬 투표'), findsOneWidget);
    expect(find.text('우승 예측'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    // 폴 예측은 마감됐고 표가 0 이라 숨는다.
    expect(find.text('폴 예측'), findsNothing);
    expect(find.text('레이스 평점'), findsNothing);

    await tester.tap(find.text('예측하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-driver-NOR')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.textContaining('내 예측 랜도 노리스'), findsOneWidget);
  });

  testWidgets('서버가 GP 를 모르면 카드를 숨긴다', (tester) async {
    final repository = PollsRepository(
      baseUrl: 'https://live.example',
      client: MockClient((_) async => http.Response('{"error":"not_found"}', 404)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RacePollsCard(race: races.first, repository: repository),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('팬 투표'), findsNothing);
  });

  testWidgets('예측 선택 시트는 번들 정적 순위가 아니라 서버 순위를 보여준다', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = PollsRepository(
      baseUrl: 'https://live.example',
      client: MockClient((_) async => http.Response(jsonEncode(_poll()), 200)),
    );
    // 번들 정적 순위(노리스 P5 · 73)와 다른 값이어야 서버 순위를 쓰는지 가려진다.
    const standings = _FakeStandingsRepository(
      StandingsSnapshot(
        driverStandings: [
          DriverStanding(
            position: 1,
            driverKo: '랜도 노리스',
            driverEn: 'Lando Norris',
            teamKo: '맥라렌',
            teamEn: 'McLaren',
            points: 412,
          ),
        ],
        constructorStandings: [],
      ),
    );
    final race = races.firstWhere((r) => !r.isCancelled);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RacePollsCard(
              race: race,
              repository: repository,
              standingsRepository: standings,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    await tester.tap(find.text('예측하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('P1 · 412'), findsOneWidget);
    expect(find.textContaining('P5 · 73'), findsNothing);
  });
}
