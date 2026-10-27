# Individual weight Gateway v2 — Step 5

`WeightService.predictWeight` now posts to **`{API_BASE_URL}/v2/weight`**, using the same `ApiConstants.baseUrl` as the main backend. Trailing slashes are normalized while preserving a configured base-path prefix. There is no separate Weight API host, internal-route call, alias probing or fallback. Gateway forwarding to downstream `/predict-weight` remains a server responsibility.

Contract confirmed by the user: multipart `files` and the original Weight API response, including `estimated_weight_kg`. File bytes, filenames, selection order, 1–4 image limit, headers, timeouts, errors, injected-client ownership and `WeightEstimate` parsing remain unchanged. No camera/gallery/result/profile/store/model/schema or UI/UX changes were made. Existing weight and photo histories use the same save flow.

Production code change: only `lib/services/weight_service.dart`. The weight endpoint assertion inside the existing combined `test/feed_test.dart` was updated; all Feed test logic and production Feed code are unchanged. Dedicated transport tests and weight documentation were added/updated.

Verification:

- Format, analyzer and `git diff --check`: clean.
- Full VM: **396 pass / 3 fail**—the same existing Beef fixed-clock readiness/demand failures.
- Relevant Chrome: **58 pass** (weight transport, photo previews/gallery, state/history integrity, cattle editing, result navigation and existing combined tests).
- Alternate `API_BASE_URL=https://gateway.example.test/api/`: **6 pass**, verifying shared configuration, prefix/trailing-slash handling, multipart bytes/counts, legacy response parsing, errors and no internal-route fallback.
- Web release: successful. No persistence migration is needed.

HTTP tests use mocks. The configured development host previously returned `ERR_NGROK_3200`; no live photo upload or native camera permission test is claimed. No Feed/backend changes, commit/push or subsequent step.
