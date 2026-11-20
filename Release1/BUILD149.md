# iPAStore build 149 — core performance

The pinned Search field no longer has a canvas rectangle around it. Only its native field fill remains; the Search title still scrolls away. App/library navigation and the parallel interactive tab animator retain their existing behavior.

## Changes

- Artwork requests use shared operations with individual subscriptions. A disappearing row releases its subscription immediately; the final subscriber cancels the network/decode work. Request identities protect new work from late cancelled completions. Queued decoder operations are cancellable, and the network slot queue removes cancelled waiters.
- Image sizes share compressed disk originals through the existing 8 MiB original-byte cache. A second cache check inside each shared operation prevents a late subscriber from starting duplicate work after an earlier completion. The disk writer recognizes shared original tokens and skips duplicate writes. Current originals take priority over legacy per-size thumbnails; corrupt-cache recovery remains supported.
- Lazy image rows release their own decoded-image state when they leave the screen. The existing bounded shared caches remain available for immediate redisplay. Cache cost uses actual bitmap row bytes rather than assuming tightly packed pixels. The decoded-cache, preview, download-size and concurrency limits are unchanged.
- Catalog preparation uses a stable partition for standard/preview editions instead of allocating and sorting singleton variant arrays. Full natural app ordering and publisher/source priority are retained. Search result materialization also runs outside the main actor.
- Prepared library snapshots retain one source revision per logical library, rather than accumulating full old catalogs. The LRU retains at most 16 libraries and a 30,000-row budget, while allowing the currently requested oversized library in full. Obsolete preparations are cancelled. Memory pressure clears reconstructible snapshots without immediately invalidating every hidden page.
- Saved custom app ordering resolves identifiers once, replacing repeated scans/removals of the remaining array. Duplicate identities, duplicate saved order entries, missing identifiers and alphabetical ordering of remaining apps keep their previous behavior.

## Repeatable measurements

A paired optimized-code benchmark on this Mac compares the frozen build 148 implementation with the new production function, alternating five samples per implementation:

| Catalog fixture | Build 148 median | Build 149 median |
| --- | ---: | ---: |
| 1,000 apps | 14.55 ms | 7.59 ms |
| 10,000 apps | 143.53 ms | 79.03 ms |
| 30,000 apps | 557.57 ms | 299.96 ms |

The 30,000-app grouping/sorting fixture is about 46% quicker in this run. This is a bounded catalog-preparation benchmark, not a claim that every app interaction is 46% quicker. Tests compare natural order, mixed standard/preview priorities and duplicate-source handling.

The instrumented custom-order fixture resolves 3,000 identifiers instead of 4,501,500 for 3,000 apps in reverse saved order. Its app-info boundary is a test fixture; this is an algorithm/work-count result, not a whole-device speed multiplier.

A controlled abandoned-row benchmark holds the decode queue while 128 requests for 16 icons at four sizes are submitted, then cancels all subscribers. Instrumenting the real ImageIO boundary records 64 decodes in build 148 and zero in the new path; the new callers release in about 0.6 ms on this Mac. This tests avoided queued work, not the speed of a completed cold decode. The phone’s uncancelled 128-request workload remains about 413 ms.

A controlled abandoned-row benchmark holds the decode queue while 128 requests for 16 icons at four sizes are submitted, then cancels all subscribers. Instrumenting the real ImageIO boundary records 64 decodes in build 148 and zero in the new path; the new callers release in about 0.6 ms on this Mac. This tests avoided queued work, not the speed of a completed cold decode. The phone’s uncancelled 128-request workload remains about 413 ms.

The revision stress check refreshes a 700-app library 60 times and retains one 700-app prepared snapshot. Separate-library budget, cache trim and reconstruction pass.

## Verification and scope

The release includes local publisher tests for byte sharing, six concurrent downloads, HTTP/size failures, surviving shared subscribers, prompt last-subscriber cancellation, immediate retry, queued decoder cancellation, background clear, stale completion isolation, legacy reuse and corrupt-cache recovery. The shared-work stress test covers 400 raced cancellations. Catalog, signing/renewal policy, compatibility, callback and package checks accompany the source.

Physical-device motion, native navigation, Search layout and artwork reports accompany the release. The Search screenshot used for local visual review is excluded from public assets. Timings and process CPU samples describe these workloads only; display-link callbacks do not prove rendered FPS or zero hitches. Instruments continued to list the iPhone offline, so a full Time Profiler trace was unavailable.

## Distribution

This development IPA needs legitimate signing. The website profile adds an installer shortcut, rather than signing the native app. Free signatures normally need renewal within seven days, and automatic renewal depends on iOS scheduling/connectivity. App-specific provisioning and third-party runtime compatibility still apply. No accounts, keys, profiles, pairing records or device identifiers are published.

## Build configuration

The final device candidate uses Release optimization with `SWIFT_ENABLE_EXPLICIT_MODULES=NO`, `CLANG_ENABLE_EXPLICIT_MODULES=NO` and `DEBUG_INFORMATION_FORMAT=dwarf` to reduce compiler scratch-space requirements on the build Mac. These are build/debug-metadata choices; they do not bypass signing or add runtime overrides. The simulator-interface Release build also passed.

## Final iPhone results

All four build 149 native reports pass. The actual Search text field moves from y=126 to y=61, then stays at y=61 through further scrolling. The 128-request artwork fixture completes in about 410 ms with 16 original-file reads; sixteen warm requests take about 0.12 ms. Both paging directions, held cancellation, six rapid reversals, all eight actual store-tab boundaries, Reduce Motion and native Back attachment pass. The app was relaunched normally without diagnostic arguments.
