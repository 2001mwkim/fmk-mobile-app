import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// 모든 주요 화면이 같은 제목 계층과 자연스러운 한국어 줄바꿈을 사용한다.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!, style: textTheme.labelSmall),
                const SizedBox(height: AppSpacing.xxs),
              ],
              Text(title, style: textTheme.headlineMedium),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(description!, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.meta,
    this.action,
  });

  final String title;
  final String? meta;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (meta != null)
          Text(meta!, style: Theme.of(context).textTheme.labelMedium),
        if (action != null) ...[const SizedBox(width: AppSpacing.xs), action!],
      ],
    );
  }
}

/// 탭은 pill/glow 대신 선택된 면의 명도 차이만 사용한다.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: const BoxDecoration(
        color: AppColors.tileSurface,
        borderRadius: AppRadius.mediumBorder,
        border: Border.fromBorderSide(BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: _SegmentButton(
                label: labelFor(value),
                selected: value == selected,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.card : Colors.transparent,
      borderRadius: AppRadius.smallBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smallBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.white : AppColors.textMuted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

enum AppStateKind { empty, loading, error }

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.message,
    this.kind = AppStateKind.empty,
    this.onRetry,
  });

  final String message;
  final AppStateKind kind;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      AppStateKind.empty => Icons.inbox_outlined,
      AppStateKind.loading => Icons.sync,
      AppStateKind.error => Icons.error_outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == AppStateKind.loading)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 24, color: AppColors.textEnded),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ],
      ),
    );
  }
}
