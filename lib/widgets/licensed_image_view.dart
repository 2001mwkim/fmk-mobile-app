import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/licensed_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class LicensedImageView extends StatelessWidget {
  const LicensedImageView({
    super.key,
    required this.image,
    required this.aspectRatio,
    required this.semanticLabel,
    this.fallbackIcon = Icons.photo_outlined,
  });

  final LicensedImage? image;
  final double aspectRatio;
  final String semanticLabel;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.largeBorder,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image == null)
              _ImageFallback(icon: fallbackIcon)
            else
              Image.network(
                image!.imageUrl,
                fit: BoxFit.cover,
                alignment: _objectPosition(image!.objectPosition),
                semanticLabel: semanticLabel,
                errorBuilder: (_, _, _) => _ImageFallback(icon: fallbackIcon),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _ImageLoading(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.background.withValues(alpha: 0.6)],
                  stops: [0.62, 1],
                ),
              ),
            ),
            if (image != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: _CreditButton(image: image!),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreditButton extends StatelessWidget {
  const _CreditButton({required this.image});

  final LicensedImage image;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const ValueKey('photo-credits-button'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showCredits(context, image),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.white,
              ),
              SizedBox(width: 5),
              Text(
                'PHOTO',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCredits(BuildContext context, LicensedImage image) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 8),
                Text(
                  'Photo credits',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Photo: ${image.author} · ${image.license}'
              '${image.modified ? ' · Cropped' : ''}',
              style: TextStyle(
                color: AppColors.slate300,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLink(context, image.sourceUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Commons 원본'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLink(context, image.licenseUrl),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('라이선스'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 출처/라이선스 링크를 외부 브라우저로 연다. 브라우저가 없거나 비활성화된
/// 기기에서는 url_launcher 가 ACTIVITY_NOT_FOUND 를 던지는데(Sentry 0.1.6+43,
/// 갤럭시 A17), 그대로 두면 미처리 예외로 올라가고 사용자는 무반응만 본다.
/// 실패는 삼켜서 스낵바로 알린다(news_screen / settings_screen 과 같은 패턴).
Future<void> _openLink(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('링크를 열 수 없습니다. 브라우저 앱이 필요해요.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Alignment _objectPosition(String? value) {
  if (value == null) return Alignment.center;
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)%\s+(\d+(?:\.\d+)?)%$',
  ).firstMatch(value.trim());
  if (match == null) return Alignment.center;
  final x = double.parse(match.group(1)!);
  final y = double.parse(match.group(2)!);
  return Alignment((x / 50) - 1, (y / 50) - 1);
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.tileSurface,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textEnded,
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.tileSurface,
      child: Center(child: Icon(icon, size: 42, color: AppColors.textEnded)),
    );
  }
}
