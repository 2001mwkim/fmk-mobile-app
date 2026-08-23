import 'package:flutter/widgets.dart';

/// A remotely hosted image whose commercial-use license has been verified on
/// its individual Wikimedia Commons file page.
class LicensedImage {
  const LicensedImage({
    required this.imageUrl,
    required this.sourceUrl,
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.modified,
    this.objectPosition,
  });

  final String imageUrl;
  final String sourceUrl;
  final String author;
  final String license;
  final String licenseUrl;

  /// True only when the registered file itself is an edited/cropped derivative.
  /// Runtime BoxFit cropping does not count as a modification.
  final bool modified;

  /// CSS-like percentages such as `50% 25%`, converted to [Alignment] by the UI.
  final String? objectPosition;
}
