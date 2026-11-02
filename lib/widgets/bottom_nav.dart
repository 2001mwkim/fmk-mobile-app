import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'glass.dart';

/// 하단 탭 바 — 화면 위에 떠 있는 글래스 캡슐(iOS 26 탭 바 방식).
///
/// 원래 웹 components/BottomNav.tsx 포팅(화면 폭 꽉 찬 불투명 바 + 윗선)이었다.
/// 2026-10 디자인 정리에서 "깔끔하지만 밋밋하다"는 피드백으로, 콘텐츠가 바
/// 아래로 흘러 비쳐 보이는 떠 있는 유리 캡슐로 바꿨다. 그래서 MainShell 은
/// Scaffold.extendBody 를 켜고, 탭 화면들은 SafeArea(bottom: false) +
/// AppLayout.pagePadding(바 높이만큼 아래 여백 포함)을 쓴다.
/// 선택된 탭 뒤엔 유리 알약이 미끄러지듯 따라간다.
///
/// 탭 구조(홈 / 일정 / 순위 / 라이브)와 (currentIndex, onTap) 시그니처는 유지.
/// 항목 순서는 app.dart 의 MainShell._screens 인덱스와 1:1 이므로 함께 수정할 것.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  // 선택된 탭은 채워진 아이콘 — iOS 탭 바처럼 색이 아니라 형태로도 구분된다.
  static const List<_NavItem> _items = [
    _NavItem(label: '홈', icon: Icons.home_outlined, activeIcon: Icons.home),
    _NavItem(
      label: '일정',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
    ),
    _NavItem(
      label: '순위',
      icon: Icons.leaderboard_outlined,
      activeIcon: Icons.leaderboard,
    ),
    _NavItem(
      label: '라이브',
      icon: Icons.sensors_outlined,
      activeIcon: Icons.sensors,
    ),
  ];

  /// 캡슐 높이. 화면 아래 여백 계산(AppLayout.pagePadding)도 이 값을 쓴다.
  static const double barHeight = 62;

  @override
  Widget build(BuildContext context) {
    // 넓은 화면(iPad 가로 등)에서는 탭이 화면 끝까지 벌어지지 않도록 본문과
    // 같은 최대 폭에 맞춘다 — 엄지/시선이 닿는 위치를 본문과 일치시킨다.
    final gutter = 16 + AppLayout.contentGutter(context);
    const radius = BorderRadius.all(Radius.circular(barHeight / 2));
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 4),
        child: DecoratedBox(
          // 유리 아래 그림자로 바닥에서 살짝 뜬 느낌.
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: GlassSurface(
            borderRadius: radius,
            blur: 28,
            tint: AppColors.navSurface.withValues(alpha: 0.72),
            padding: const EdgeInsets.all(5),
            child: SizedBox(
              height: barHeight - 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _items.length;
                  return Stack(
                    children: [
                      // 선택 알약 — 탭이 바뀌면 그 자리로 미끄러진다.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        left: itemWidth * currentIndex,
                        top: 0,
                        bottom: 0,
                        width: itemWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.12),
                            borderRadius: radius,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < _items.length; i++)
                            Expanded(
                              child: _NavButton(
                                item: _items[i],
                                isActive: i == currentIndex,
                                onTap: () {
                                  if (i != currentIndex) {
                                    HapticFeedback.selectionClick();
                                  }
                                  onTap(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 탭 선택은 레드가 아니라 흰색 — 레드는 '진행 중' 의미에만 쓴다.
    final color = isActive ? AppColors.white : AppColors.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: AppType.caption.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
