# Individual Feed Result v2 — Step 4

Individual evaluation now opens the v2 result renderer and can save a new immutable `FeedPlan` snapshot. Backend requirement, nutrient supply, adequacy/status, warnings, assumptions/defaults, coverage and confidence are displayed structurally, including nested/unknown backend metadata and supplied units. No nutrient formula, threshold, missing value, percentage or confidence score is synthesized. Absent/null coverage and confidence do not create panels.

For Dairy, any explicit backend `not_fully_evaluable` marker displays **Belum dapat dievaluasi penuh**. Adequacy detail is not presented as a nutrient classification; contradictory structured `cukup`/`kurang` or equivalent status codes are neutralized in the presentation. Actual requirement/supply numbers and confidence values remain visible. The complete original response, including those codes, is retained unchanged in storage. No local numeric comparison derives sufficiency.

## Stored evaluation and compatibility

- New native evaluations carry explicit `planType: nutritionEvaluation`, immutable `nutritionRequest` (the exact supported context/selected ingredient IDs and kg/day), and the Step 2 `nutritionSnapshot` response wrapper. No fake generic target/body condition is assigned; those legacy fields are null for native evaluations.
- Input portions represent the user's submitted as-fed amounts, not backend-generated recommendations. `FarmStatus.planReady` excludes this type regardless of backend adequacy, preventing automatic dashboard readiness/stock demand. No stock ledger transaction is created.
- FarmStore reserves collision-safe IDs, validates the current active Twin and submitted context, then appends on save. Different payloads under an existing ID are rejected; identical retries remain idempotent. Failed writes preserve state and the visible draft. Stage, DIM, category or weight changes can make an unsaved evaluation stale; already-saved/archived snapshots remain readable.
- Legacy ration JSON remains unchanged, including original timestamps, portions, notes and optional Step 2 response-only snapshots. The legacy result UI remains for plans without nutrition snapshots; existing snapshot-enriched histories render their backend data without fabricating missing request details.
- Farm schema/minimum reader stays **5**. The new `planType` and `nutritionRequest` keys are allowed explicitly; unknown types and mismatched request/response/portions fail validation. Previous readers reject these new keys before they can silently discard them. No full migration or storage rewrite is added.
- The existing pure Twin-to-nutrition mapper is reused for draft/save context validation; FarmStore does not perform HTTP calls. Nullable legacy target/body-condition types are guarded on legacy-only paths.

## Scope and verification

Group Feed models, services, screens and tests are unchanged. Backend, other flows, Dairy context mappings, milk conversions and persisted Twin schemas are unchanged. The only new route is the individual result path; saving/back-navigation completes that existing individual flow.

- Format: clean; analyzer: **0 issues**; `git diff --check`: clean.
- Full VM: **390 pass / 3 fail**, with the same pre-existing Beef clock-dependent readiness/demand failures. New result/storage tests pass.
- Relevant Chrome: **149 pass**, including result/input flows, API v2, plan compatibility, migrations and Group Feed.
- Historical Step 3 reader: **3 pass**—legacy accepted; new evaluations rejected on load/restore without replacing disk/history. The generated new fixture also passes the current reader.
- Web release: successful. Tests use mock backend responses; live backend verification is not claimed.

Intentional limits: renderer remains structural because nested backend nutrient schemas are not specified; no approval/activation workflow, decision engine, Group v2 migration or new scientific rules. No commit/push or subsequent step.
