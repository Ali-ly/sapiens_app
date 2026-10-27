# Individual Feed v2 — Step 3

Individual calculator now selects an active Twin, reads its category/context, loads `GET /v2/feeds/{production_category}`, accepts explicit user `as_fed_kg_day` for selected backend feed IDs, then calls `POST /v2/nutrition`. The category is read-only. Generic target/body-condition selection and the generic-Beef acknowledgement are removed from this route. Group Feed and its legacy transport are unchanged; historical Feed Result routes remain available.

## Context rules

- Null category: no category inference/catalog call; direct the user to classify the Twin.
- Weight: current Twin `estimatedWeight`; missing weight blocks submission and can be recorded through the existing dialog.
- Beef: recorded purpose → `penggemukan` / `pembibitan`. Missing purpose blocks submission. Target weight and actual growth ADG are not target ADG, so `target_adg_kg_day` is omitted. No generic target is chosen in the calculator.
- Dairy: explicit Twin-to-backend stage mapping, confirmed by the user:
  - `preWeaning` → `preweaning_calf`; `heifer` → `growing_heifer`; `firstPregnancy` → `pregnant_heifer`.
  - `fresh` → `fresh`; `early` → `early_lactation`; `mid` → `mid_lactation`; `late` → `late_lactation`.
  - `dry` → `dry_far_off`; `closeUp` → `close_up`.
  - Heifer mappings require a female Twin without recorded calving. `newborn`, `weaned`, `breedingReady`, and `calving` have no confirmed direct mapping and block submission with an explanation; no automatic phase change is made.
  - Actual calving supplies existing calendar DIM; missing DIM stays omitted. No age/day threshold is introduced.
- Milk history is in **liters**, not kg: `milk_kg_day` is omitted. No density conversion is invented. `parity_group` uses only the current actual calving record's validated explicit parity: 1 → `primiparous`, >=2 → `multiparous`. That field is the user's lactation/parity baseline (or its validated increment on calving). Missing parity is omitted, even when multiple cycles are recorded; cycle count is not substituted for parity. Numeric fat/protein facts are not present in the Twin, so those optional fields are omitted. This limit is visible in the Dairy calculator.
- Inactive Twin: no catalog/evaluation, history retained.

Catalog IDs, names and quantities are independent of the three legacy ingredient labels. Select at least one ingredient and enter a positive finite quantity per selected item; decimal commas are accepted. No local fiber rule, nutritional threshold, formula or default quantity is introduced. Empty/error/duplicate-ID/mismatched-category catalogs cannot yield an evaluation. Errors support retry without v1 fallback.

Category/cow changes clear old selections and quantities. Request generations ignore late catalog replies after switching, reclassification or disposal. Any store change during submission invalidates that acknowledgement; submitted Twin context is also checked again. Submission controls prevent duplicate requests. Editing quantities clears old success feedback.

## Step boundary

Step 3 stops at a basic acknowledgement: “Evaluasi nutrisi diterima. Hasil belum disimpan sebagai rencana.” It does not open the legacy Feed Result screen or turn an evaluation into a ration. No v2 plan is saved yet; result presentation/save is a subsequent step. Model/schema/storage and legacy plan eligibility guards are unchanged.

`FeedCalculatorScreen` uses injectable v2 catalog/evaluation functions for deterministic HTTP/widget testing; default functions are the real `FeedService` v2 endpoints. A small `CattleNutritionContext` mapper isolates recorded-fact projection. Beef and Dairy Feeding link to this same individual calculator; the Beef entry no longer applies the legacy generic-ration restriction to Pembibitan. Existing Twin health, milk, reproduction, Beef domain and Group Feed workflows are retained.


## Final verification — confirmed Dairy mapping

The follow-up changes only the context mapper, its model/widget regressions and this document. No backend, schema, Twin history, Group Feed or final Feed Result implementation changes. Fifteen additional tests cover the confirmed aliases, unmapped phases, explicit/unknown parity and ordinary-heifer consistency. Complete and partial milk records remain omitted from `milk_kg_day` because they are recorded in liters.

- Format: 3 changed Dart files formatted, final pass 0 changes.
- `flutter analyze`: no issues.
- Full VM (`--concurrency=1`): **377 pass / 3 fail**. The same existing Beef fixed-clock vs real plan-clock cases fail (plan readiness and stock demand); no unrelated clock fix is included.
- Relevant Chrome suites: **84 pass**, including individual input/HTTP payloads, context mapping, Beef/Dairy profiles, navigation and Group Feed.
- Web release: successful. `git diff --check`: clean.
- Group Feed, legacy Feed Result, Step 1 transport and Step 2 persisted models/schema remain unchanged. Existing migrations execute in the full VM suite; no new migration is needed.
- HTTP integration uses mock responses. Backend enum names are confirmed by the user; live production backend verification is not claimed.

No commit/push or subsequent step.
