import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';
import '../services/fmk_home_widget_bridge.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// 홈 "빠른 설정" 카드: 알림 설정 이동 + 홈 위젯 추가(pin 요청).
///
/// 위젯이 이 앱의 메인 기능인데 발견 경로가 런처 롱프레스뿐이라, 홈에서
/// 한 번에 추가할 수 있는 진입점을 만든다. 위젯이 2종(일정·라이브 / 순위)
/// 이라 먼저 바텀시트로 종류를 고르게 한다(미지원 런처는 수동 안내 스낵바).
class HomeQuickActionsCard extends StatelessWidget {
  const HomeQuickActionsCard({super.key, this.pinRequester});

  /// 테스트 주입 지점. 기본은 [FmkHomeWidgetBridge.requestPinWidget].
  final Future<bool> Function(String qualifiedAndroidName)? pinRequester;

  Future<void> _pickAndRequestPin(BuildContext context) async {
    final provider = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => const _WidgetPickerSheet(),
    );
    if (provider == null || !context.mounted) return;

    final requester =
        pinRequester ??
        (name) => FmkHomeWidgetBridge.requestPinWidget(
          qualifiedAndroidName: name,
        );
    final launched = await requester(provider);
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('이 런처는 바로 추가를 지원하지 않아요. 홈 화면을 길게 눌러 위젯을 추가해 주세요.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: _QuickActionTile(
              icon: Icons.notifications_outlined,
              title: '알림 설정',
              subtitle: '세션 시작 전에 알림',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
          Container(width: 1, height: 52, color: AppColors.rowBorder),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.widgets_outlined,
              title: '위젯 추가',
              subtitle: '홈 화면에서 바로 확인',
              onTap: () => _pickAndRequestPin(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// 위젯 종류 선택 바텀시트. 선택한 Provider 의 qualifiedAndroidName 을 pop 한다.
class _WidgetPickerSheet extends StatelessWidget {
  const _WidgetPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '추가할 위젯 선택',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _WidgetOptionTile(
              icon: Icons.calendar_today_outlined,
              title: '일정 · 라이브 위젯',
              subtitle: '다음 세션 일정, 라이브 순위와 최근 결과',
              onTap: () => Navigator.of(
                context,
              ).pop(fmkHomeWidgetProviderQualifiedName),
            ),
            const SizedBox(height: 8),
            _WidgetOptionTile(
              icon: Icons.bar_chart,
              title: '챔피언십 순위 위젯',
              subtitle: '드라이버·팀 Top 5와 순위 변동',
              onTap: () => Navigator.of(
                context,
              ).pop(fmkStandingsWidgetProviderQualifiedName),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetOptionTile extends StatelessWidget {
  const _WidgetOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tileSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.faintBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.resultChipSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.redSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.resultChipSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.redSoft),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
