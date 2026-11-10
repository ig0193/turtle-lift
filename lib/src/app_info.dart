/// The app's version, as `pubspec.yaml` declares it (`version: 0.1.0+1`).
///
/// A constant rather than a plugin read (`package_info_plus`): the About row
/// is the only reader, and `test/profile_personal_polish_test.dart` fails the
/// moment this drifts from the pubspec. Bump both together.
library;

/// The marketing version, before the `+`.
const String kAppVersion = '0.1.0';

/// The build number, after the `+`.
const int kAppBuild = 1;

/// "Version 0.1.0 (1)", as the About block prints it.
String appVersionLabel() => 'Version $kAppVersion ($kAppBuild)';
