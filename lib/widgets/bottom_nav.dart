import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 웹 components/BottomNav.tsx 의 Flutter 포팅.
///
/// 웹 nav: h-[86px] border-t border-white/10 bg-[#0c0e18] px-4 pt-3, items-start
///   - 활성: font-extrabold text-red-500
///   - 비활성: font-semibold text-[#959bb6]
///   - 아이콘 25px, 라벨 10px, 아이콘-라벨 gap 6
///
/// 탭 구조(홈 / 일정 / 순위 / 소식)와 (currentIndex, onTap) 시그니처는 유지.
/// 항목 순서는 app.dart 의 MainShell._screens 인덱스와 1:1 이므로 함께 수정할 것.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem(label: '홈', icon: Icons.home_outlined),
    _NavItem(label: '일정', icon: Icons.calendar_today_outlined),
    _NavItem(label: '순위', icon: Icons.bar_chart),
    _NavItem(label: '소식', icon: Icons.article_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navSurface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 86,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _items[i],
                      isActive: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
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
    final color = isActive ? AppColors.red : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 25, color: color),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
