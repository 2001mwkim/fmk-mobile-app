import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../services/notification_settings_controller.dart';
import '../services/notification_service.dart';

const String _instagramUrl = 'https://www.instagram.com/formula_magazine.kr';
const String _contactEmail = 'contact@formulamagazine.kr';
const String _feedbackSubject = '비아 포뮬러 오류 제보 / 기능 제안';
const String _f1dbUrl = 'https://github.com/f1db/f1db';
const String _privacyPolicyUrl = 'https://www.formulamagazine.kr/privacy';

// 웹 설정 페이지 전용 색.
const Color _muted = AppColors.muted; // #7880a0
const Color _sectionMuted = AppColors.textMuted; // 섹션 제목/배지 텍스트
const Color _nameMuted = AppColors.nameMuted; // #aab0cc
const Color _tileSurface = AppColors.tileSurface; // #0e1018
const Color _fmkDivider = AppColors.divider; // white/7
const Color _faintBorder = AppColors.faintBorder; // white/6

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            _BackButtonRow(),
            SizedBox(height: 14),
            _Header(),
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

class _BackButtonRow extends StatelessWidget {
  const _BackButtonRow();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.chevron_left,
              size: 24,
              color: AppColors.white,
            ),
          ),
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
            'VIA FORMULA',
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

class _NotificationCard extends StatefulWidget {
  const _NotificationCard();

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await notificationSettingsController.load();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _loading = false;
    });
  }

  Future<void> _update({bool? allSessions30m, bool? raceOnly30m}) async {
    if (_saving) return;
    setState(() => _saving = true);

    NotificationSettingsUpdateResult result;
    try {
      result = await notificationSettingsController.update(
        allSessions30m: allSessions30m,
        raceOnly30m: raceOnly30m,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnackBar(context, '알림 설정을 저장하지 못했습니다.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _preferences = result.preferences;
      _saving = false;
    });

    if (result.permissionDenied) {
      _showSnackBar(context, '알림 권한이 꺼져 있어 알림을 켤 수 없습니다.');
    } else if (result.preferences.hasAnyEnabled) {
      _showSnackBar(context, '알림 예약을 업데이트했습니다.');
    } else {
      _showSnackBar(context, '예약된 세션 알림을 취소했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: _CardHeaderRow(
                title: '알림 설정',
                description: '한국시간 기준 세션 시작 30분 전에 로컬 알림을 보냅니다.',
                badge: '로컬 알림',
              ),
            ),
            const _RowDivider(),
            _NotificationToggleRow(
              title: '전체 세션 30분 전 알림',
              description: 'FP1, FP2, FP3, 스프린트, 퀄리파잉, 레이스 전에 알림',
              value: _preferences.allSessions30m,
              enabled: !_loading && !_saving,
              onChanged: (value) => _update(allSessions30m: value),
            ),
            const _RowDivider(),
            _NotificationToggleRow(
              title: '레이스 30분 전 알림',
              description: '레이스 세션만 시작 30분 전에 알림',
              value: _preferences.raceOnly30m,
              enabled: !_loading && !_saving,
              onChanged: (value) => _update(raceOnly30m: value),
            ),
            const _RowDivider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: _InsetNote(
                '두 옵션을 모두 켜면 전체 세션 알림 기준으로만 예약되어 레이스 알림은 중복되지 않습니다.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.red,
            inactiveThumbColor: _nameMuted,
            inactiveTrackColor: _tileSurface,
            onChanged: enabled ? onChanged : null,
          ),
        ],
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
    // 배지는 제목 줄에만 두고 설명은 카드 전체 폭을 쓰게 한다.
    // (설명까지 배지 옆 좁은 컬럼에 넣으면 불필요한 줄바꿈이 생긴다.)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            AppChip(label: badge, variant: AppChipVariant.neutral),
          ],
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
        color: AppColors.card,
        borderRadius: _radius,
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
                          '비아 포뮬러',
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
            // 번들 자산 라이선스 표기(전문: assets/flags/LICENSE.md).
            const _DlRow(label: '국기 아이콘', value: 'circle-flags · MIT'),
            const _DlRow(label: '시간 기준', value: '한국시간 KST'),
            _DlRow(
              label: '개인정보 처리방침',
              value: '보기',
              onTap: () =>
                  _openExternalUri(context, Uri.parse(_privacyPolicyUrl)),
            ),
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
