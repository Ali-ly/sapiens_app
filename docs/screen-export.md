# Screen export for redesign

The opt-in `tool/export_all_screens_test.dart` renders the actual Flutter pages with a memory repository, synthetic cattle, recorded API fixtures, a placeholder photo picker and a fake backup-file picker. No production storage or live API is used. Every page class in `lib/features` is represented, including the private calculation-detail route reached through normal navigation. Long content is paginated with overlapping viewports; screenshots preserve the actual back navigation and bottom navigation where applicable.

Latest export (28 October 2026): 18 page classes, 202 page/state scenarios, 329 PNGs; 390×844 logical viewport at 1.5× pixel ratio. Includes Beef/Dairy, every profile tab, add/edit forms, all Dairy stage forms and six event forms, milk modes/units/corrections, manual/photo weight, gallery, catalog entries, nutrition input/results/details, guards, archive/reopen, mode reset and restore confirmations, loading/error/empty/busy/read-only states.

```sh
flutter test tool/export_all_screens_test.dart --dart-define=SCREEN_EXPORT=true --dart-define=SCREEN_DIR=/absolute/path/to/screens
```

Run the export explicitly: it is skipped unless SCREEN_EXPORT=true. Screenshots are an external design artifact, not production seed data or new app features. Native camera/gallery/permission/file/share/keyboard UI belongs to the OS and is outside this app's design surface. This is not every possible input/error-string combination or a live E2E test. Existing regression tests continue to cover behavior independently.

The source result-page changes were already in the working tree: simplified summary, dedicated calculation-details page and raw JSON dialog. They are preserved. Responsive wrapping for the details link and numeric requirement values prevents overflow at compact widths/200% text. Result tests now follow that existing details navigation rather than expecting removed disclosures.
