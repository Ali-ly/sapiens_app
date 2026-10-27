# Migration fixtures

Synthetic, non-user data in the actual persisted shapes from this repository:

- `unversioned` and `2`: `22c533c` FarmStore encodeCattle/exportData.
- `3`: historical membership-group shape retained by the schema-4 decoder.
- `4`: schema 4 plus Phase 1 foundation version 1, with real exit/health/event
  records and existing IDs that migration must preserve.
- `5`: reviewed expected schema-5 migration of fixture 4; deterministic digests
  use the specified slot-v1/farm-v1 JSON array seeds (UTF-8, SHA-256).

Weights share timestamps, photos share both name and bytes. Times include raw
local strings without known offsets and explicit +07:00 strings. These values
must remain literal, not acquire a guessed UTC zone, capture time, DOB or category.
No group membership workflow is reintroduced.

Run `python3 tool/generate_migration_fixtures.py` after editing JSON. The generated
Dart bundle lets VM and Chrome use identical data without a production asset or
browser filesystem adapter. CI checks the bundle for drift.

- `5-beef`: expected upgrade Phase 4 atas fixture `5`, dengan farm foundation 3,
  ledger kosong dan namespace Beef 2/histori kosong; Shared Twin 2 dan Dairy 1
  dipertahankan. Fixture `5` lama tetap menjadi input migrasi Phase 3.

- `5-dairy`: expected upgrade Phase 5 atas `5-beef`, namespace Dairy 2
  dengan records/milk kosong. Root foundation 3, Shared Twin 2 dan Beef 2
  identik dengan Phase 4; fixture `5-beef` tetap input historis.
