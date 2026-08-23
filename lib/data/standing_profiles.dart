import '../models/licensed_image.dart';
import '../models/standing_profile.dart';

const _ccBySa40 = 'https://creativecommons.org/licenses/by-sa/4.0';
const _ccBy40 = 'https://creativecommons.org/licenses/by/4.0';

String _commonsFileUrl(String fileName) =>
    'https://commons.wikimedia.org/wiki/File:${Uri.encodeComponent(fileName)}';

String _commonsImageUrl(String fileName) =>
    'https://commons.wikimedia.org/wiki/Special:Redirect/file/'
    '${Uri.encodeComponent(fileName)}?width=1280';

LicensedImage _australianGpPhoto(
  String fileName, {
  String? objectPosition,
  bool modified = false,
}) => LicensedImage(
  imageUrl: _commonsImageUrl(fileName),
  sourceUrl: _commonsFileUrl(fileName),
  author: 'Yu Chu Chin',
  license: 'CC BY-SA 4.0',
  licenseUrl: _ccBySa40,
  modified: modified,
  objectPosition: objectPosition,
);

LicensedImage _chineseGpPhoto(
  String fileName, {
  String? objectPosition,
  bool modified = false,
}) => LicensedImage(
  imageUrl: _commonsImageUrl(fileName),
  sourceUrl: _commonsFileUrl(fileName),
  author: 'Liauzh',
  license: 'CC BY 4.0',
  licenseUrl: _ccBy40,
  modified: modified,
  objectPosition: objectPosition,
);

/// 2026 portraits verified against their individual Wikimedia Commons pages.
/// Missing photos intentionally stay null until a suitable licensed portrait is
/// reviewed; official F1/CDN imagery must never be used as a fallback.
final Map<String, DriverProfile> driverProfilesByCode = {
  'ANT': DriverProfile(
    code: 'ANT',
    nationalityKo: '이탈리아',
    image: _australianGpPhoto(
      'Kimi Antonelli at the Melbourne Walk during the 2026 Australian Grand Prix (028A7923).jpg',
      objectPosition: '52% 22%',
    ),
  ),
  'HAM': const DriverProfile(code: 'HAM', nationalityKo: '영국'),
  'RUS': DriverProfile(
    code: 'RUS',
    nationalityKo: '영국',
    image: _australianGpPhoto(
      'Podium celebration at the 2026 Australian Grand Prix (028A8767).jpg',
      objectPosition: '50% 18%',
    ),
  ),
  'LEC': DriverProfile(
    code: 'LEC',
    nationalityKo: '모나코',
    image: _australianGpPhoto(
      'Charles Leclerc at the Melbourne Walk during the 2026 Australian Grand Prix (028A8637).jpg',
      objectPosition: '50% 24%',
    ),
  ),
  'NOR': DriverProfile(
    code: 'NOR',
    nationalityKo: '영국',
    image: _australianGpPhoto(
      'Lando Norris at the Melbourne Walk during the 2026 Australian Grand Prix (028A7958).jpg',
      objectPosition: '50% 20%',
    ),
  ),
  'PIA': DriverProfile(
    code: 'PIA',
    nationalityKo: '호주',
    image: _australianGpPhoto(
      'Oscar Piastri at the Melbourne Walk during the 2026 Australian Grand Prix (028A8607).jpg',
      objectPosition: '50% 22%',
    ),
  ),
  'VER': DriverProfile(
    code: 'VER',
    nationalityKo: '네덜란드',
    image: _australianGpPhoto(
      'Max Verstappen at the Red Bull Fan Zone – Crown Riverwalk, Melbourne (028A7677).jpg',
      objectPosition: '50% 18%',
    ),
  ),
  'GAS': const DriverProfile(code: 'GAS', nationalityKo: '프랑스'),
  'HAD': DriverProfile(
    code: 'HAD',
    nationalityKo: '프랑스',
    image: _australianGpPhoto(
      'Isack Hadjar at the Melbourne Walk during the 2026 Australian Grand Prix (028A8753).jpg',
      objectPosition: '50% 22%',
    ),
  ),
  'LAW': DriverProfile(
    code: 'LAW',
    nationalityKo: '뉴질랜드',
    image: _australianGpPhoto(
      'Liam Lawson and Arvid Lindblad at the Red Bull Fan Zone – Crown Riverwalk, Melbourne (028A7751).jpg',
      objectPosition: '30% 20%',
    ),
  ),
  'BEA': DriverProfile(
    code: 'BEA',
    nationalityKo: '영국',
    image: _australianGpPhoto(
      'Oliver Bearman at the Melbourne Walk during the 2026 Australian Grand Prix (028A7963).jpg',
      objectPosition: '50% 18%',
    ),
  ),
  'COL': DriverProfile(
    code: 'COL',
    nationalityKo: '아르헨티나',
    image: _australianGpPhoto(
      'Franco Colapinto at the Melbourne Walk during the 2026 Australian Grand Prix (028A8704).jpg',
      objectPosition: '50% 20%',
    ),
  ),
  'LIN': DriverProfile(
    code: 'LIN',
    nationalityKo: '영국',
    image: _australianGpPhoto(
      'Liam Lawson and Arvid Lindblad at the Red Bull Fan Zone – Crown Riverwalk, Melbourne (028A7751).jpg',
      objectPosition: '72% 20%',
    ),
  ),
  'SAI': DriverProfile(
    code: 'SAI',
    nationalityKo: '스페인',
    image: _australianGpPhoto(
      'Carlos Sainz Jr. at the Melbourne Walk during the 2026 Australian Grand Prix (028A7953).jpg',
      objectPosition: '50% 18%',
    ),
  ),
  'ALB': DriverProfile(
    code: 'ALB',
    nationalityKo: '태국',
    image: _australianGpPhoto(
      'Alex Albon at the Melbourne Walk during the 2026 Australian Grand Prix (028A8626).jpg',
      objectPosition: '50% 18%',
    ),
  ),
  'OCO': const DriverProfile(code: 'OCO', nationalityKo: '프랑스'),
  'BOR': DriverProfile(
    code: 'BOR',
    nationalityKo: '브라질',
    image: _australianGpPhoto(
      'Gabriel Bortoleto at the Melbourne Walk during the 2026 Australian Grand Prix (028A8581).jpg',
      objectPosition: '50% 20%',
    ),
  ),
  'ALO': const DriverProfile(code: 'ALO', nationalityKo: '스페인'),
  'HUL': DriverProfile(
    code: 'HUL',
    nationalityKo: '독일',
    image: _chineseGpPhoto(
      '2026 Chinese GP - Nico Hulkenberg (cropped).jpg',
      objectPosition: '50% 18%',
      modified: true,
    ),
  ),
  'BOT': DriverProfile(
    code: 'BOT',
    nationalityKo: '핀란드',
    image: _australianGpPhoto(
      'Valtteri Bottas at the Melbourne Walk during the 2026 Australian Grand Prix (028A8412).jpg',
      objectPosition: '50% 20%',
    ),
  ),
  'PER': const DriverProfile(code: 'PER', nationalityKo: '멕시코'),
  'STR': const DriverProfile(code: 'STR', nationalityKo: '캐나다'),
};

/// 2026 car photos. Every entry below was checked on its individual Commons
/// file page and is published by Liauzh under CC BY 4.0.
final Map<String, TeamProfile> teamProfilesByKo = {
  '메르세데스': TeamProfile(
    teamKo: '메르세데스',
    countryKo: '독일',
    baseKo: '브래클리, 영국',
    carName: 'W17',
    image: _chineseGpPhoto('2026 Chinese GP - Mercedes - W17.jpg'),
  ),
  '페라리': TeamProfile(
    teamKo: '페라리',
    countryKo: '이탈리아',
    baseKo: '마라넬로, 이탈리아',
    carName: 'SF-26',
    image: _chineseGpPhoto(
      '2026 Chinese GP - Ferrari - Lewis Hamilton - Qualifying.jpg',
    ),
  ),
  '맥라렌': TeamProfile(
    teamKo: '맥라렌',
    countryKo: '영국',
    baseKo: '워킹, 영국',
    carName: 'MCL40',
    image: _chineseGpPhoto(
      '2026 Chinese GP - McLaren - Lando Norris - Qualifying.jpg',
    ),
  ),
  '레드불 레이싱': TeamProfile(
    teamKo: '레드불 레이싱',
    countryKo: '오스트리아',
    baseKo: '밀턴킨스, 영국',
    carName: 'RB22',
    image: _chineseGpPhoto(
      '2026 Chinese GP - Red Bull - Max Verstappen - Qualifying.jpg',
    ),
  ),
  '알핀': TeamProfile(
    teamKo: '알핀',
    countryKo: '프랑스',
    baseKo: '엔스톤, 영국',
    carName: 'A526',
    image: _chineseGpPhoto(
      '2026 Chinese GP - Alpine - Pierre Gasly - Qualifying.jpg',
    ),
  ),
  '레이싱 불스': TeamProfile(
    teamKo: '레이싱 불스',
    countryKo: '이탈리아',
    baseKo: '파엔차, 이탈리아',
    carName: 'VCARB 03',
    image: _chineseGpPhoto(
      '2026 Chinese GP - Racing Bulls - Liam Lawson - Qualifying.jpg',
    ),
  ),
  '하스': TeamProfile(
    teamKo: '하스',
    countryKo: '미국',
    carName: 'VF-26',
    image: _chineseGpPhoto(
      '2026 Chinese GP - Haas - Esteban Ocon - Qualifying.jpg',
    ),
  ),
  '윌리엄스': TeamProfile(
    teamKo: '윌리엄스',
    countryKo: '영국',
    baseKo: '그로브, 영국',
    carName: 'FW48',
    image: _chineseGpPhoto(
      '2026 Chinese GP - Williams - Alex Albon - Qualifying.jpg',
    ),
  ),
  '아우디': TeamProfile(
    teamKo: '아우디',
    countryKo: '독일',
    baseKo: '힌빌, 스위스',
    carName: 'R26',
    image: _chineseGpPhoto('2026 Chinese GP - Audi - R26.jpg'),
  ),
  '애스턴 마틴': TeamProfile(
    teamKo: '애스턴 마틴',
    countryKo: '영국',
    baseKo: '실버스톤, 영국',
    carName: 'AMR26',
    image: _chineseGpPhoto('2026 Chinese GP - Aston Martin - AMR26.jpg'),
  ),
  '캐딕락': TeamProfile(
    teamKo: '캐딕락',
    countryKo: '미국',
    carName: 'MAC-26',
    image: _chineseGpPhoto('2026 Chinese GP - Cadillac - MAC-26.jpg'),
  ),
};
