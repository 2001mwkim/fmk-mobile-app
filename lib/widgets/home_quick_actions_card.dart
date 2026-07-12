import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';
import '../services/fmk_home_widget_bridge.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// 홈 "빠른 설정" 카드: 알림 설정 이동 + 홈 위젯 추가(pin 요청).
///
/// 위젯이 이 앱의 메인 기능인데 발견 경로가 런처 롱프레스뿐이라, 홈에서
/// 한 번에 추가할 수 있는 진입점을 만든다(미지원 런처는 수동 안내 스낵바).
class HomeQuickActionsCard extends StatelessWidget {
  const HomeQuickActionsCard({super.key, this.pinRequester});

  /// 테스트 주입 지점. 기본은 [FmkHomeWidgetBridge.requestPinWidget].
  final Future<bool> Function()? pinRequester;

  Future<void> _requestPin(BuildContext context) async {
    final requester = pinRequester ?? FmkHomeWidgetBridge.requestPinWidget;
    final launched = await requester();
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
              onTap: () => _requestPin(context),
            ),
          ),
        ],
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
