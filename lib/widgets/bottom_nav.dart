import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 웹 components/BottomNav.tsx 의 Flutter 포팅.
///
/// 웹 nav: border-t border-white/10 bg-[#0c0e18] px-4, 아이콘 25px, 라벨 10px.
/// 웹의 고정 h-[86px] 는 모바일에서 옮기지 않는다 — 시스템 제스처 인셋이
/// SafeArea 로 별도 추가되므로 고정 높이를 쓰면 내용물(~55px) 아래 죽은
/// 여백이 기기 공통으로 생긴다. 높이는 내용물 기준으로 잡고, 제스처 영역은
/// SafeArea 가 기기별로 알아서 확보한다(3버튼 내비 폰에선 인셋 0).
///
/// 탭 구조(홈 / 일정 / 순위 / 라이브)와 (currentIndex, onTap) 시그니처는 유지.
/// 항목 순서는 app.dart 의 MainShell._screens 인덱스와 1:1 이므로 함께 수정할 것.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem(label: '홈', icon: Icons.home_outlined),
    _NavItem(label: '일정', icon: Icons.calendar_today_outlined),
    _NavItem(label: '순위', icon: Icons.bar_chart),
    _NavItem(label: '라이브', icon: Icons.sensors_outlined),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
