# lib/core/constants/app_config.dart

## Purpose
Build-time default constants (app name, upload limits, matching thresholds, map/campus geography, pagination) that can be overridden at runtime by Firestore `config/app`.

## Key members
- `AppConfig` (abstract final class) — static consts: `appName`, email domain fallbacks, upload size/type limits, image processing settings, Lost & Found match thresholds, `pageSize`, `functionsEnabledFallback`, campus map bounds/zoom levels, tile server URL/user agent/attribution, `walkingSpeed`, `surveyMaxAccuracyMetres`.

## Dependencies & relationships
No imports — pure constants. Used throughout the app (map screens, upload validators, Lost & Found matching UI, printout, `tile_cache.dart`, `validators.dart`) as compile-time fallback values; many are overridden by the live `RemoteConfig` from `firebase_providers.dart`.

## Notable behavior / gotchas
Comments flag that the OpenStreetMap tile server discourages bulk pre-downloading and that the tile URL should be switched to a provider whose terms allow offline caching before release — described as a config change, not a rebuild. Campus bounds are real coordinates for KPR Institute of Engineering and Technology.
