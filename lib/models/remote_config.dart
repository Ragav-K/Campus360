import '../core/constants/app_config.dart';

/// The `config/app` document — publicly readable, admin-writable.
/// Keeps campus-specific policy out of the binary (§26).
class RemoteConfig {
  const RemoteConfig({
    required this.allowedEmailDomains,
    required this.requireCollegeEmail,
    required this.maxDocumentBytes,
    required this.functionsEnabled,
    required this.tileUrlTemplate,
    this.campusCenterLat,
    this.campusCenterLng,
  });

  final List<String> allowedEmailDomains;
  final bool requireCollegeEmail;
  final int maxDocumentBytes;

  /// False ⇒ hide/disable OTP, matching and notification features with an
  /// explicit "unavailable" state instead of faking them client-side (§40).
  final bool functionsEnabled;

  /// Map tile source. Configurable so the campus can move to a provider whose
  /// terms permit offline caching without shipping a new build.
  final String tileUrlTemplate;

  final double? campusCenterLat;
  final double? campusCenterLng;

  /// Domains to enforce at the form level. Empty ⇒ accept any domain.
  List<String> get enforcedDomains => requireCollegeEmail ? allowedEmailDomains : const [];

  static const fallback = RemoteConfig(
    allowedEmailDomains: AppConfig.allowedEmailDomainsFallback,
    requireCollegeEmail: AppConfig.requireCollegeEmailFallback,
    maxDocumentBytes: AppConfig.maxDocumentBytesFallback,
    functionsEnabled: AppConfig.functionsEnabledFallback,
    tileUrlTemplate: AppConfig.tileUrlTemplate,
  );

  factory RemoteConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return fallback;
    return RemoteConfig(
      allowedEmailDomains:
          (m['allowedEmailDomains'] as List?)?.map((e) => e.toString()).toList() ?? fallback.allowedEmailDomains,
      requireCollegeEmail: m['requireCollegeEmail'] as bool? ?? fallback.requireCollegeEmail,
      maxDocumentBytes: ((m['maxUploadMb'] as num?)?.toInt() ?? 20) * 1024 * 1024,
      functionsEnabled: m['functionsEnabled'] as bool? ?? fallback.functionsEnabled,
      tileUrlTemplate: m['tileUrlTemplate'] as String? ?? fallback.tileUrlTemplate,
      campusCenterLat: (m['campusCenter']?['lat'] as num?)?.toDouble(),
      campusCenterLng: (m['campusCenter']?['lng'] as num?)?.toDouble(),
    );
  }
}
