# Startup and artwork performance · build 122 installed

Base:121, retaining119 refresh reliability and116 navigation. User explicitly approved installation and testing of the sealed122 candidate. Installation and bounded phone checks are complete; details below.

Findings:
- Discovery decodes every saved library sequentially before publishing any of them. Today's library can wait behind all other feeds.
- Cache restoration uses a Boolean guard; a second caller can continue before the first restore completes.
- Artwork makes a new URLSession per image, preventing connection reuse; sizes of the same image can download separately.
- Eager shelf pages can start offscreen image work before visible artwork.

Work plan: prioritize/publish today's cache first, coalesce restoration, order network refresh with Today first, reuse image sessions and in-flight image data, bound offscreen work, then validate startup/cache invariants, build/package, ask install approval and verify on the phone if connected. Do not promise instantaneous uncached remote content. Preserve all archive/signing/binary safeguards and121 category behavior.

Progress/checks/artifact/install: pending. Backups in work/speed122/baseline. Update this record before stopping.

Implemented so far:
- Shared restoration task; read and publish the persisted daily library first at user-initiated priority, then read other catalogs in a utility worker. If the priority catalog is absent/empty, its network refresh starts while the other caches decode. Cached content stays usable; daily selection and real refresh errors remain.
- Network pass puts the selected library first. Full catalogs, subscriptions, retry/backoff and uncached publisher validation remain intact.
- Library snapshots now also prepare Today category grouping off-main. A prepare API lets Today warm up to nine unique first-page icons. Horizontal pages defer offscreen work while keeping explicit stable heights; vertical shelves remain stable.
- Artwork actor reuses one ephemeral URLSession and shares original bytes/in-flight requests across thumbnail sizes. Encoded memory capped8MB/48items, individual cached originals2MB; existing decoded40MB/preview12MB limits,12MB download limit,6active downloads and disk pruning remain. Clear Artwork Cache clears encoded memory too.
- Product navigation no longer re-encodes/writes the entire download history when only Recent changed. Redownload state uses a set lookup rather than repeatedly scanning up to2,000 records.

Checks already passing: startup fixture (Today cached first4ms,8libraries/all2,000apps35ms on this Mac, zero network), existing model regressions; production artwork HTTP actor (same-URL sharing, memory reuse/clear, exact bytes,404,12MB cap,6peakrequests across22requests/6connections); live catalog HTTP/update checks. Initial device Release/preview builds PASS. Final history regression suite and final incremental builds running. No phone interaction/testing yet this update. No122 package/approval yet. Do not confuse local fixture timing with real device/end-to-end artwork loading.

Final local validation:
- Release/model suite PASS, including the new startup and history-index checks. Final fixture: featured cache first3ms, eight catalogs/2,000apps and prepared selected rows38ms, zero network requests. These are Mac fixture measurements, not iPhone timings.
- Artwork HTTP checks PASS:22requests reuse6connections, peak6active; same-URL concurrent callers share one request, cached originals reuse/clear correctly, bytes match,404 and >12MB responses rejected.
- Catalog HTTP checks PASS: changed/new/removed apps, no-cache requests,503retry, permanent404, relative redirected URLs and in-flight coalescing.
- Final iPhone Release and preview builds PASS. Strict package checks PASS: CRC, deep signatures,128keychain groups, native worker selectors, extension versions.
-116 pager hash unchanged:441f0889ce5c0c95fc3947333f44041cf5e5c6c00e45ce7ba866fee2b66411bd.

Sealed candidate: outputs/IPAStore-builds/iPAStore-1.0.0-rc.23-build122.ipa
SHA256:cf4d283681aa9fe9611c31e0d1765d7b99d44fc9c908a074c0214654697911aa
Report:Validation/candidate-checks-1.0.0-rc.23.json
Await exact-candidate install/test approval.121 remains last confirmed installed. Phone tests should cover Today reopening/artwork, tab changes, product navigation and full-library/search availability. No downloads, guest launches, signing/account changes or cache erasure needed. First-ever network content and unavailable publisher artwork cannot be guaranteed instant.


Installed and tested:
- User explicitly approved rc.23build122. Initial iloader attempt reported device not found. After installer restart/refresh, USB and network entries appeared; restored the existing saved login and selected USB. Reconfirmed the sealed SHA256. iloader reported Operation completed / Sign & Install App. Read-only device inventory independently confirms iPAStore1.0.0build122.
- Today showed the persisted Mangayomi library with card artwork, library icon and app row populated. Home/reopen showed the existing populated content during opening.
- Opened the featured library:1app, All Apps only, icon and compact metadata intact. Opened its app page: header/screenshot artwork, icon, Get, version and information populated; no download started.
- Search tab showed Recent and Browse All Apps with icons and installed Open states. Query test was inconclusive because keyboard forwarding appended unintended characters; restored Capture Keyboard to off and cleared the query. Do not claim a physical filtered-search pass. Local prepared-search/model checks pass.
- Stores showed loaded library icons/counts, including AltGallery58apps. Opened AltGallery, scrolled down to Games/All Apps and moved its horizontal shelf. Populated rows and controls were present after settling; no crash observed. Intermediate remote drag/transition snapshots sometimes showed blank scroll areas before the settled content. This remote control path cannot establish frame smoothness or a zero-stutter guarantee.
- Fresh-process restart through the development device API succeeded. First subsequent phone screen check showed Today, the same daily library, header/icon and app row populated without a visible loading indicator. This is a functional cached-startup check, not a precise device cold-start benchmark or an uncached network test. Do not report the Mac fixture's3ms as phone timing.
- No IPA downloads, guest launches, account/signing changes, library changes or artwork-cache erasure. Viewing the product updates Recent normally. Phone left on Today. No private phone-screen captures saved into the project.

Current active source/package:122. All local validation listed above passed; bounded device navigation/artwork/startup checks complete with the stated limits. Uncached or unavailable publisher content still depends on the network. No further work is pending for this candidate.
