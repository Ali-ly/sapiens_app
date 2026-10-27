# FeedPlan v2 snapshot — Step 2

`FeedPlan` gains optional `nutritionSnapshot: FeedNutritionSnapshot`. The composed value holds an explicit `ProductionCategory` and the immutable, lossless `NutritionResponse` DTO from Step 1. It exposes requirement, supply, adequacy, warnings, coverage, assumptions and defaultsUsed; all backend response fields (including unknown nested metadata) are retained. An omitted section stays omitted, null stays null, and no requirement, formula, sufficiency decision or category is inferred.

Persisted shape (inside an existing plan):

```json
{
  "nutritionSnapshot": {
    "version": 1,
    "productionCategory": "beef",
    "response": {
      "requirement": {},
      "supply": {},
      "adequacy": {},
      "warnings": [],
      "coverage": {},
      "assumptions": []
    }
  }
}
```

Empty sections above only illustrate the shape; serialization never inserts them. Version 1 describes the new persisted snapshot wrapper, independently of backend API v2 and farm schema 5.

`plan.productionCategory` exposes the snapshot category; historical plans return null even if they contain legacy Beef context. Response category, if supplied, must match the explicit snapshot category. `matches` additionally checks snapshot category against current cattle classification. Dairy snapshots cannot coexist with a Beef-specific plan context.

## History and reader safety

Legacy constructors/required ration fields, validation, portions/units, warning/notes and original timestamp strings remain unchanged. Legacy plan JSON does not gain new keys or synthetic snapshots. The existing unversioned/2/3/4 migration chain still preserves plan contents. Mixed old/new plan histories round-trip through farm snapshot and backup codecs.

The farm envelope remains schema/minimum reader **5**. The allowlist in `FarmPayloadShape` now recognizes `nutritionSnapshot`. The previous allowlist rejects this field before decoding, preventing older supported readers from ignoring it and rewriting the snapshot. This was verified using the previous plan/rules/payload-shape source in an isolated reader copy: old backup accepted, new snapshot rejected on decode/load/restore, no failed-load write or failed-restore replacement. Unknown wrapper versions/metadata and invalid category are rejected. Backend-owned fields inside `response` remain extensible.

Existing `FarmStore.savePlan` idempotency compares the complete JSON, so a same-ID change/removal of snapshot data is not an update: it is rejected. A new evaluation must be saved under a new plan ID. Write failures leave memory and disk untouched; archiving a Twin retains its plan snapshots.

## Step boundary

This is an additive snapshot on the existing ration model. No UI flow, HTTP service, automatic response-to-ration mapping, stock aggregation, nutrition approval, or legacy feeding capability guard is changed. Existing required plan inputs and `savePlan` eligibility rules still apply, including the current Dairy workflow guard. Dairy snapshot encoding/backup is supported; unlocking its end-to-end UI/save flow and standalone nutrition-only plans belongs to subsequent integration. No fake ration, age, target or body condition is created to make a v2 response fit the legacy constructor.

No storage rewrite, full migration, dependency change, commit/push or next step.

## Verification (26 October 2026)

- 14 new snapshot VM tests pass, including nested immutability, sparse/null response fields, Beef/Dairy serialization, category mismatch, mixed old/new history, same-ID conflict/removal, failed write/restore/load, archive retention and legacy migrations.
- Relevant Chrome suites: **85 pass** (`feed_plan_v2`, `feed_api_v2`, `feed`, `schema_migration`), run with `--concurrency=1`. The first parallel attempt stalled while loading a suite; the sequential retry completed in 15 seconds.
- Previous reader probes: **3 pass** (old accepted, new load/restore rejected safely).
- Full VM: **342 pass, 4 fail**. The same four Beef clock-sensitive failures were reproduced before Step 1; their fixed store clock and real plan creation clock are unchanged here. No unrelated fix is included.
- Analyzer clean; web release build succeeds; format and `git diff --check` clean.
