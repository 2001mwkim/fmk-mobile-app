import 'licensed_image.dart';

class DriverProfile {
  const DriverProfile({
    required this.code,
    required this.nationalityKo,
    this.image,
  });

  final String code;
  final String nationalityKo;
  final LicensedImage? image;
}

class TeamProfile {
  const TeamProfile({
    required this.teamKo,
    required this.countryKo,
    required this.carName,
    this.baseKo,
    this.image,
  });

  final String teamKo;
  final String countryKo;
  final String carName;
  final String? baseKo;
  final LicensedImage? image;
}
