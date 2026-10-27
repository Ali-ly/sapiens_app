# API v2 — Step 1

Contract source: backend JSON supplied by the user, 26 October 2026.

`lib/models/feed_api_v2.dart` contains transport-only DTOs; storage/schema and domain `FeedPlan` are unchanged.

- `FeedService.fetchFeeds(productionCategory: ..., client: ...)` calls `GET /v2/feeds/{beef|dairy}`. `FeedCatalogResponse` exposes category, count and immutable ingredient list. Ingredients expose stable ID, display name and nullable nutritional values. Backend metadata/unknown fields are preserved without default nutrient values. `category`, `valid_for`, `profile_status` and `confidence_note` retain backend JSON until their exact types/enums are confirmed.
- `FeedService.calculateNutrition(request: ..., client: ...)` calls `POST /v2/nutrition`. `NutritionCattleContext.beef` and `.dairy` serialize the supplied context fields, omitting unspecified optional values. `NutritionFeedItem` sends stable `feed_id` and user-provided `as_fed_kg_day`. Category derives from context; no Beef/Dairy mismatch can be constructed.
- `NutritionResponse` preserves optional `requirement`, `supply`, `adequacy`, `warnings`, `coverage`, `assumptions`, `defaults_used` and unknown fields, including nulls. Their nested schemas were not specified: these sections deliberately remain immutable JSON, not invented nutrient requirements or inferred success/adequacy.
- Both endpoints use configured `API_BASE_URL`, existing API error decoding, 30-second timeout and injected-client ownership. Explicit response-category mismatches are rejected. No retries/fallback to v1 and no local nutrition formulas.

## Current boundary after Step 6

Individual routes use only the v2 catalog/nutrition methods and native evaluation snapshots. The obsolete individual `calculatePlan` wrapper and `FeedResponseMapper` were removed. `calculateFeed` is retained unchanged solely because `GroupFeedService` still calls it; `FeedRation` remains its parser. Neither endpoint nor Group behavior was migrated in this cleanup. Legacy model codecs, Beef context and archive rendering remain necessary for existing histories; the legacy result view no longer has an unsaved-ration creation/save branch. Weight uses `/v2/weight` with its existing parser. See [cleanup report](legacy-individual-cleanup.md).

The verification below records Step 1; the cleanup report contains current checks.

## Verification

- Format: 3 Dart files, clean on second pass.
- `flutter analyze`: no issues.
- New contract suite: 8 VM tests and 8 Chrome tests pass.
- Full VM: 328 pass, 4 fail. All four failures reproduce without Step 1 in an isolated copy (46 pass / same 4 failures in the two Beef suites). Existing Beef fixtures use a fixed store clock (`2026-10-26T10:00Z`) while plan creation uses the real clock; future-plan guards make these tests time-dependent. No unrelated clock/domain change is included in Step 1.
- `flutter build web --release`: succeeds.
- `git diff --check`: clean.
