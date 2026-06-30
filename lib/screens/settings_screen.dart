import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';

const String _instagramUrl = 'https://www.instagram.com/formula_magazine.kr';
const String _contactEmail = 'contact@formulamagazine.kr';
const String _feedbackSubject = '포매코 F1 캘린더 오류 제보 / 기능 제안';
const String _f1dbUrl = 'https://github.com/f1db/f1db';

// 웹 설정 페이지 전용 색.
const Color _muted = Color(0xFF7880A0); // #7880a0
const Color _sectionMuted = Color(0xFF959BB6); // 섹션 제목/배지 텍스트
const Color _nameMuted = Color(0xFFAAB0CC); // #aab0cc
const Color _tileSurface = Color(0xFF0E1018); // #0e1018
const Color _fmkDivider = Color(0x12FFFFFF); // white/7
const Color _faintBorder = Color(0x0FFFFFFF); // white/6

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            _Header(),
            SizedBox(height: 20),
            _Section(title: '일정 관리', child: _CalendarCard()),
            SizedBox(height: 20),
            _Section(title: '알림', child: _NotificationCard()),
            SizedBox(height: 20),
            _Section(title: '포뮬러 매거진 코리아', child: _FmkCard()),
            SizedBox(height: 20),
            _Section(title: '앱 정보', child: _AppInfoCard()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FMK F1 CALENDAR',
            style: TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '설정',
            style: TextStyle(
              fontSize: 26,
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: _sectionMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: () => _showSnackBar(context, '캘린더 추가 기능은 준비 중입니다.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _CardHeaderRow(
            title: '캘린더에 추가',
            description: '시즌 전체 일정과 레이스 일정을 캘린더에 추가하는 기능을 준비 중입니다.',
            badge: '준비 중',
          ),
          SizedBox(height: 16),
          _InsetNote('추후 캘린더 구독 방식 또는 앱에서 직접 추가하는 방식으로 제공할 예정입니다.'),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: () => _showSnackBar(context, '알림 설정 기능은 준비 중입니다.'),
      child: const _CardHeaderRow(
        title: '알림 설정',
        description: '세션 시작 전 알림 기능은 추후 앱 버전에서 제공될 예정입니다.',
        badge: '앱 버전 예정',
      ),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({
    required this.title,
    required this.description,
    required this.badge,
  });

  final String title;
  final String description;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: _muted,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AppChip(label: badge, variant: AppChipVariant.neutral),
      ],
    );
  }
}

class _InsetNote extends StatelessWidget {
  const _InsetNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _tileSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: _muted,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FmkCard extends StatelessWidget {
  const _FmkCard();

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C0F0E), Color(0xFF1A1030), Color(0xFF141828)],
        ),
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: _radius,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x33EF4444)), // red-500/20
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FORMULA MAGAZINE KOREA',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.redSoft,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '한국 F1 팬을 위한 모터스포츠 미디어',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '포매코는 F1 뉴스, 카드뉴스, 레이스 가이드를 한국 팬들에게 쉽고 빠르게 전합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _nameMuted,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0x1A000000), // black/10
                border: Border(top: BorderSide(color: _fmkDivider)),
              ),
              child: Column(
                children: [
                  _LinkRow(
                    title: '인스타그램 보러가기',
                    chevronColor: AppColors.redSoft,
                    onTap: () =>
                        _openExternalUri(context, Uri.parse(_instagramUrl)),
                  ),
                  const _RowDivider(),
                  _LinkRow(
                    title: '제휴 및 문의',
                    subtitle: _contactEmail,
                    onTap: () => _openExternalUri(
                      context,
                      Uri(scheme: 'mailto', path: _contactEmail),
                    ),
                  ),
                  const _RowDivider(),
                  _LinkRow(
                    title: '오류 제보 / 기능 제안',
                    onTap: () => _openExternalUri(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: _contactEmail,
                        queryParameters: {'subject': _feedbackSubject},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.chevronColor = _muted,
  });

  final String title;
  final String? subtitle;
  final Color chevronColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: chevronColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _faintBorder)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '포매코 F1 캘린더',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'v0.1.0',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '한국시간 기준 F1 일정과 결과를 확인하는 팬용 캘린더입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _muted,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _DlRow(
              label: '데이터 출처',
              value: 'F1DB · CC BY 4.0',
              showTopBorder: false,
              onTap: () => _openExternalUri(context, Uri.parse(_f1dbUrl)),
            ),
            const _DlRow(label: '시간 기준', value: '한국시간 KST'),
            const _DlRow(label: '사용 분석', value: 'Vercel Analytics'),
          ],
        ),
      ),
    );
  }
}

class _DlRow extends StatelessWidget {
  const _DlRow({
    required this.label,
    required this.value,
    this.onTap,
    this.showTopBorder = true,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      decoration: BoxDecoration(
        border: showTopBorder
            ? const Border(top: BorderSide(color: _faintBorder))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: _nameMuted,
                fontWeight: FontWeight.w700,
                decoration: onTap == null ? null : TextDecoration.underline,
                decorationColor: const Color(0x33FFFFFF), // white/20
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _fmkDivider);
  }
}

Future<void> _openExternalUri(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }

  if (opened || !context.mounted) return;

  _showSnackBar(context, '외부 링크를 열 수 없습니다.');
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
