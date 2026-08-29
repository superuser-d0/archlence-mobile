/// The version this build says it is, in the one place a user can see it.
///
/// A literal rather than a runtime read of the package: `package_info_plus`
/// is a plugin, a platform channel and a dependency, for one string that is
/// known at compile time.
///
/// The cost of a literal is that it can drift from `pubspec.yaml` without
/// anything noticing — and it had, by a whole major version. The Settings
/// screen said `v0.1.0` while `pubspec.yaml` had been moved to `1.0.0`, so
/// the store listing and the app itself would have disagreed about what was
/// installed. Nothing could have caught it: a test asserting the text would
/// have asserted the same stale literal back.
///
/// So `test/app_version_test.dart` reads `pubspec.yaml` instead, and requires
/// this to agree with it. Bump the two together or the suite fails.
library;

const String appVersion = '1.0.0';
