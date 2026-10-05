/// Build-time defaults. Anything a campus admin might reasonably change lives
/// in Firestore at `config/app` and overrides these at runtime (§26).
abstract final class AppConfig {
  static const appName = 'Campus360';

  /// Fallback only. The live value comes from `config/app.allowedEmailDomains`.
  /// Empty list + [requireCollegeEmailFallback] false ⇒ any domain accepted.
  static const allowedEmailDomainsFallback = <String>[];
  static const requireCollegeEmailFallback = false;

  // Upload limits (client-side pre-check; Storage rules enforce the real limit).
  static const maxImageBytes = 5 * 1024 * 1024;
  static const maxDocumentBytesFallback = 20 * 1024 * 1024;
  static const allowedDocumentExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  static const allowedDocumentMimeTypes = ['application/pdf', 'image/jpeg', 'image/png'];

  // Image processing before upload (§37).
  static const imageMaxDimension = 1600;
  static const imageJpegQuality = 80;

  // Lost & Found matching presentation (§11). Scoring itself is server-side.
  static const matchLikelyThreshold = 0.80;
  static const matchPossibleThreshold = 0.60;
  static const matchMinimumThreshold = 0.45;

  // Pagination
  static const pageSize = 20;

  /// True when Cloud Functions are deployed. When false the app must *disable*
  /// server-backed features with a visible "unavailable" state rather than
  /// faking them on the client (§40). Overridden by `config/app.functionsEnabled`.
  static const functionsEnabledFallback = true;

  // ---- Campus map -----------------------------------------------------------
  //
  // Real coordinates for KPR Institute of Engineering and Technology, taken
  // from OpenStreetMap. The bounds are padded well beyond the campus so the
  // prefetch covers the approach roads and the gates too.

  static const campusLat = 11.0766;
  static const campusLng = 77.1421;

  static const campusNorth = 11.0810;
  static const campusSouth = 11.0722;
  static const campusEast = 77.1470;
  static const campusWest = 77.1372;

  static const mapInitialZoom = 17.0;
  static const mapMinZoom = 15.0;
  static const mapMaxZoom = 19.0;

  /// Zoom levels stored for offline use. 16–19 covers "whole campus" through
  /// "individual building", and for an area this small totals only a couple of
  /// hundred tiles.
  static const prefetchMinZoom = 16;
  static const prefetchMaxZoom = 19;

  /// Default tile source. Overridden at runtime by `config/app.tileUrlTemplate`.
  ///
  /// NOTE: OpenStreetMap's public tile server discourages bulk pre-downloading.
  /// A campus-sized prefetch is tiny, but before releasing this to students
  /// point the template at a provider whose terms allow offline caching
  /// (MapTiler or Stadia free tier). That is a config change, not a rebuild.
  static const tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Tile servers block requests without an identifying agent.
  static const tileUserAgent = 'Campus360/0.1 (student project; contact via campus IT)';

  static const mapAttribution = '© OpenStreetMap contributors';

  /// Walking pace used for ETAs, metres per second (~4.9 km/h).
  static const walkingSpeed = 1.35;

  /// A GPS fix worse than this is too vague to record as a location.
  static const surveyMaxAccuracyMetres = 25.0;
}
