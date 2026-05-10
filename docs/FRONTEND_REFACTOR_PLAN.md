Frontend Refactor Plan

Purpose

Make the Flutter frontend easier to read, test, and extend while minimizing runtime risk.

Principles

- Incremental: Small, reversible changes that preserve behavior.
- Non-destructive: Keep legacy code paths until replacements are validated.
- Measured: Run `flutter analyze` and smoke tests after each step.

Proposed folder layout

lib/
  features/
    map/
      map_screen.dart (thin wrapper)
      map_provider.dart (caches polylines/markers, encapsulates map state)
      map_widgets/
    network/
      network_browser.dart
    complaints/
      complaints_screen.dart
  widgets/  (shared presentational widgets)
  providers/ (lightweight providers like AppState, MapProvider)
  services/  (api, local storage, location, realtime)

Incremental steps

1. Documentation (this file + CONTRIBUTING.md).
2. Create `features/map` and a `MapProvider` that mirrors existing map behavior; do NOT remove existing map code yet.
3. Inject `MapProvider` into the app alongside `AppState` and update `home_screen.dart` to prefer `MapProvider` for cached polylines/markers.
4. Run `flutter analyze` and manual smoke testing (map interactions, live location toggle).
5. Extract `road_network_browser` into `features/network` with clear props and stateless presentation.
6. Gradually split `AppState` into focused providers; keep a compatibility layer to avoid breaking screens.
7. Move JSON parsing into background `compute` functions or services.
8. Implement marker clustering or viewport-limited marker rendering if dataset scale requires it.

Validation checklist (per step)

- No analyzer errors
- Home screen map loads and interactions remain functional
- Live/manual selection behaves as intended
- No regressions in complaint submission flow

Notes

- I'll perform only non-breaking changes by default. For larger refactors you must approve replacement of legacy code paths.

