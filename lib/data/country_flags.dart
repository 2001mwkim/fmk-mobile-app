// 웹 lib/countryFlags.ts 포팅.
// Race 모델에 필드를 추가하지 않고 countryKo 값만으로 국기 이모지를 매핑한다.
const Map<String, String> _countryFlagMap = {
  '호주': '🇦🇺',
  '중국': '🇨🇳',
  '일본': '🇯🇵',
  '바레인': '🇧🇭',
  '사우디아라비아': '🇸🇦',
  '미국': '🇺🇸',
  '캐나다': '🇨🇦',
  '모나코': '🇲🇨',
  '스페인': '🇪🇸',
  '오스트리아': '🇦🇹',
  '영국': '🇬🇧',
  '벨기에': '🇧🇪',
  '헝가리': '🇭🇺',
  '네덜란드': '🇳🇱',
  '이탈리아': '🇮🇹',
  '아제르바이잔': '🇦🇿',
  '싱가포르': '🇸🇬',
  '멕시코': '🇲🇽',
  '브라질': '🇧🇷',
  '카타르': '🇶🇦',
  '아랍에미리트': '🇦🇪',
};

/// countryKo에 해당하는 국기 이모지. 매핑이 없으면 빈 문자열.
///
/// 앱 화면은 [getCountryFlagAsset](벡터)을 우선 사용한다 — 이모지는 기기·런처
/// 마다 룩이 제각각이라 프리미엄 톤이 안 나온다. 이모지는 홈 위젯
/// (RemoteViews 텍스트)처럼 이미지가 어려운 곳의 폴백으로 유지한다.
String getCountryFlag(String countryKo) => _countryFlagMap[countryKo] ?? '';

// ISO 3166-1 alpha-2 코드 매핑 — assets/flags/{code}.svg (circle-flags, MIT).
const Map<String, String> _countryCodeMap = {
  '호주': 'au',
  '중국': 'cn',
  '일본': 'jp',
  '바레인': 'bh',
  '사우디아라비아': 'sa',
  '미국': 'us',
  '캐나다': 'ca',
  '모나코': 'mc',
  '스페인': 'es',
  '오스트리아': 'at',
  '영국': 'gb',
  '벨기에': 'be',
  '헝가리': 'hu',
  '네덜란드': 'nl',
  '이탈리아': 'it',
  '아제르바이잔': 'az',
  '싱가포르': 'sg',
  '멕시코': 'mx',
  '브라질': 'br',
  '카타르': 'qa',
  '아랍에미리트': 'ae',
};

/// countryKo에 해당하는 원형 국기 SVG 에셋 경로. 매핑이 없으면 null(이모지 폴백).
String? getCountryFlagAsset(String countryKo) {
  final code = _countryCodeMap[countryKo];
  return code == null ? null : 'assets/flags/$code.svg';
}
