import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

const String _instagramUrl = 'https://www.instagram.com/formula_magazine.kr';
const String _contactEmail = 'contact@formulamagazine.kr';
const String _feedbackSubject = '포매코 F1 캘린더 오류 제보 / 기능 제안';
const String _f1dbUrl = 'https://github.com/f1db/f1db';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SettingsHeader(),
            const SizedBox(height: 18),
            _CalendarSettingsSection(),
            const SizedBox(height: 18),
            _NotificationSettingsSection(),
            const SizedBox(height: 18),
            _FmkSection(),
            const SizedBox(height: 18),
            _AppInfoSection(),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FMK F1 CALENDAR',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '설정',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '일정 관리',
      child: _SettingsCard(
        children: [
          _SettingsTile(
            title: '캘린더에 추가',
            description: '시즌 전체 일정과 레이스 일정을 캘린더에 추가하는 기능을 준비 중입니다.',
            badge: '준비 중',
            icon: Icons.calendar_month_outlined,
            onTap: () => _showSnackBar(context, '캘린더 추가 기능은 준비 중입니다.'),
          ),
          _InsetNote(text: '추후 캘린더 구독 방식 또는 앱에서 직접 추가하는 방식으로 제공할 예정입니다.'),
        ],
      ),
    );
  }
}

class _NotificationSettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '알림',
      child: _SettingsCard(
        children: [
          _SettingsTile(
            title: '알림 설정',
            description: '세션 시작 전 알림 기능은 추후 앱 버전에서 제공될 예정입니다.',
            badge: '앱 버전 예정',
            icon: Icons.notifications_none_outlined,
            onTap: () => _showSnackBar(context, '알림 설정 기능은 준비 중입니다.'),
          ),
        ],
      ),
    );
  }
}

class _FmkSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '포뮬러 매거진 코리아',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          border: Border.all(color: AppColors.red.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FORMULA MAGAZINE KOREA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '한국 F1 팬을 위한 모터스포츠 미디어',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '포매코는 F1 뉴스, 카드뉴스, 레이스 가이드를 한국 팬들에게 쉽고 빠르게 전합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _ActionRow(
              title: '인스타그램 보러가기',
              trailingColor: AppColors.red,
              onTap: () {
                _openExternalUri(context, Uri.parse(_instagramUrl));
              },
            ),
            _ActionRow(
              title: '제휴 및 문의',
              subtitle: _contactEmail,
              onTap: () {
                _openExternalUri(
                  context,
                  Uri(scheme: 'mailto', path: _contactEmail),
                );
              },
            ),
            _ActionRow(
              title: '오류 제보 / 기능 제안',
              onTap: () {
                _openExternalUri(
                  context,
                  Uri(
                    scheme: 'mailto',
                    path: _contactEmail,
                    queryParameters: {'subject': _feedbackSubject},
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '앱 정보',
      child: _SettingsCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '포매코 F1 캘린더',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Text(
                      'v0.1.0',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '한국시간 기준 F1 일정과 결과를 확인하는 팬용 캘린더입니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _InfoRow(
            label: '데이터 출처',
            value: 'F1DB · CC BY 4.0',
            onTap: () {
              _openExternalUri(context, Uri.parse(_f1dbUrl));
            },
          ),
          _InfoRow(label: '시간 기준', value: '한국시간 KST'),
          _InfoRow(label: '사용 분석', value: 'Vercel Analytics'),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.description,
    required this.badge,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final String badge;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(label: badge),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InsetNote extends StatelessWidget {
  const _InsetNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingColor = AppColors.textMuted,
  });

  final String title;
  final String? subtitle;
  final Color trailingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: trailingColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                decoration: onTap == null ? null : TextDecoration.underline,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
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
