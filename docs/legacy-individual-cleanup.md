# Legacy individual cleanup — Step 6

## Removed

- `FeedService.calculatePlan`: obsolete individual `/calculate-feed` wrapper, including Cattle/FeedPlan/legacy mapper imports. Individual routes already use `fetchFeeds` and `calculateNutrition`.
- `lib/services/feed_response_mapper.dart`: no production caller remained. Archive tests now construct recorded `FeedPlan` fixtures directly under `test/helpers/legacy_feed_plan_fixture.dart`; no retired individual API/parser is needed to seed history.
- `BeefFeedContext.capture`: retired individual legacy-context creation convenience; archive fixtures now supply the recorded revision/purpose/phase explicitly. Its decoder/serializer and compatibility checks remain.
- Legacy individual result's unreachable unsaved-ration save action, busy/error fields and creation-only header branch. Existing legacy ration views retain reading, clipboard copy, day scaling and close navigation. V2 evaluation results/save are unchanged.
- Two obsolete HTTP tests asserting the retired individual generic contract and blanket rejection of Dairy/breeding/calf contexts. V2 contract/context/flow tests remain. The immutable-plan regression now exercises v2; legacy import/stock guards still have archive coverage.

## Intentionally retained

`GroupFeedService.calculate` still calls **`FeedService.calculateFeed` → `/calculate-feed`**, then **`FeedRation.parse`**. These are live Group dependencies, not dead endpoints/parsers. Their transport/parser implementation, Group services/models/screens and Group behavior are byte-identical. The Group UI test changed only its individual archive-fixture setup/import; its Group operations and assertions are unchanged.

Legacy `FeedPlan` codecs/fields, `BeefFeedContext`, validation, stock eligibility and archive rendering are required for existing records and backups. They are not routes for current individual HTTP calculations. No schema/migration/storage change was made.

Weight already uses `/v2/weight` after Step 5; no retired individual weight route remains in `lib`. `WeightEstimate`, `ApiResponse`, image helpers and camera/gallery/history paths are live and remain unchanged. No backend, dependency, formula, threshold, Group migration or subsequent step was added.

## Fixtures and prior clock failures

Historical fixtures now require explicit creation time. `BeefEnvironment` uses its injected Store clock instead of the removed mapper's wall clock. The three previously failing Beef readiness/demand tests remain in place with their assertions unchanged and now pass; no production time/eligibility guard was relaxed. Archive fixture IDs remain unique within each test isolate.

## Verification

- Format check: clean; analyzer: **0 issues**; `git diff --check`: clean.
- **Full VM: 398 pass, 0 fail. Full Chrome: 398 pass, 0 fail.**
- Web release build: successful.
- Group production source, shared Group HTTP/parser implementation, persistence codecs/schema/storage, Weight and the v2 renderer/transport behavior verified unchanged. Legacy context serialization is unchanged; only its retired creation factory was removed. Schema and history compatibility remain covered by full migration/round-trip suites.
- `calculatePlan` / `FeedResponseMapper` have no references in `lib` or `test`. The only retained legacy feed endpoint is Group's compatibility transport. HTTP tests use mocks; live backend verification is not claimed.

No commit/push.
