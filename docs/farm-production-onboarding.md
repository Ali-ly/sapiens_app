# Farm production onboarding

The app now chooses Sapi Pedaging or Sapi Perah before the main application. The choice persists in the existing `productionSystems` field (schema 5, unchanged). A previously selected single system opens directly. Legacy null/Both snapshots retain their original data until a user explicitly selects and confirms a single system. Backup/restore remains available at the initial picker.

Home, Profile and Add Cattle show the selected farm identity. New cattle inherit the single farm category. Profiles present only their current production domain first, followed by shared identity, care and history; retained opposite-domain namespaces do not create extra panels. Missing/deleted Twins no longer fall back to an old widget snapshot.

## Switching types

Profile and Settings route through one explicit switch screen. Switching to the other type requires a dialog explaining permanent deletion, including the number of active and inactive cattle. Cancelling or choosing the current type preserves all data.

`FarmStore.selectFarmProduction` atomically replaces the existing snapshot: select the new single system; clear all cattle (including their weights, media, health, status, events and Beef/Dairy histories), individual feed plans/evaluations and legacy individual group memberships. Farm ID, farmer/farm metadata, reminders, independent groups/group plans and stock remain. Ordinary cattle archive/exit behavior is unchanged. External backups already copied by the user remain external backups.

The command requires explicit deletion intent when individual data exists and compares an opaque full-snapshot revision at queued write time. Any intervening write invalidates confirmation. Failed validation/disk writes do not publish a new in-memory snapshot. Switching closes routes to the app root and resets main tab state.

## Compatibility

No schema, backend or nutrition changes. Existing schema 5 readers, null/Both backups and domain namespaces remain supported by storage. Both is retained for legacy decoding/internal compatibility, but new app setup offers only Pedaging or Perah. Settings no longer offers a non-destructive dropdown that bypasses the switch flow. Existing navigation tests now explicitly configure their farm fixture; historical model/migration tests retain their coverage.

## Verification

Format check: 150 files, zero changes. `flutter analyze --no-pub`: no issues. Full VM suite: 429 passed. Relevant Chrome suite (onboarding, shared core, individual feed, groups, app flow, Beef and Dairy UI): 99 passed. Web release build and `git diff --check`: passed. Manual browser preview was blocked by declined localhost-origin permission; no workaround attempted. New tests cover first selection/reload, inherited cattle category, domain profile separation, clear/reset confirmation/cancellation, active/inactive and individual history removal, retained farm/groups/stock, same-type no-op, failed write, intervening mutation, deleted profile behavior, legacy Both and narrow layouts.

## Files changed

- `lib/app.dart`
- `lib/screens/beef/beef_module_screen.dart`
- `lib/screens/cattle/add_cattle_screen.dart`
- `lib/screens/cattle/cattle_profile_screen.dart`
- `lib/screens/cattle/widgets/shared_twin_panel.dart`
- `lib/screens/dairy/dairy_module_screen.dart`
- `lib/screens/home/command_center_screen.dart`
- `lib/screens/profile/farm_production_screen.dart`
- `lib/screens/profile/farm_settings_screen.dart`
- `lib/screens/profile/user_profile_screen.dart`
- `lib/state/farm_store.dart`
- `test/app_flow_test.dart`
- `test/cattle_editing_test.dart`
- `test/command_center_test.dart`
- `test/farm_production_flow_test.dart`
- `test/feed_flow_test.dart`
- `test/groups_ui_test.dart`
- `test/shared_core_ui_test.dart`
