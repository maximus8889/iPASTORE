# Storefront refinement — November 7, 2026

User requested this pass after rc.3/build102. Preserve signing/pairing/guest-runtime testing deferral. Do not claim identical Apple internals or universal compatibility.

Requested changes:
- Restore actual library artwork everywhere; expand verified publisher suggestions with icons and consistent compact cards matching Stores. Truncate compact titles/descriptions; full details remain on library pages.
- Library overview has no persistent search field. Search belongs in the full app/category listing opened from More Apps/Show All, activated by one search button. Hide the button while the field is open. Apply button-activated search to Suggestions too. Keep global Search tab.
- Remove the large duplicate Show All tile at the end of shelves; retain section header Show All.
- Inline Get/Open/measured progress/cancel on every small app row, using the existing prerequisite-checked install coordinator. Avoid nested buttons/links.
- Refresh toolbar is the circular-arrow icon and invokes the shared refresh-all operation.
- Professional Today hero: only library icon, bounded title/summary, closer-look CTA; gradient from its actual icon colors. Today's app shelves contain only that day's library.
- Animated directional tab slides, respecting Reduce Motion and horizontal shelves/back gestures.
- Investigate opening delay and optimize image decoding/caching and derived catalog recomputation. Verify real improvements without claiming a measured speedup until measured.

Status: inspection/research started. Latest installed baseline is rc.3/build102. Keep a durable implementation/build/validation/deployment checkpoint here.

## Implementation checkpoint

Source changes now compile in both simulator preview and iPhone engine. Shared library cards are used by Stores and Suggestions (64pt artwork, bounded one-line title/subtitle, same 100pt base card height). Three new verified publisher feeds added: StikDebug, Ignited, Feather; ten publisher icons bundled with URL/hash provenance in Resources/LibraryArtworkSources.json. Offline artwork appears before metadata fetch finishes. Network artwork uses bounded downloads, ImageIO thumbnail decoding away from the main actor, coalesced requests and bounded memory/disk caches; product screenshots are lazy.

Today has a single library icon/title/summary/CTA with colors sampled from its icon border. Its shelves use only the featured library's cached index. Removed trailing Show All tile; section header Show All remains. Category title/Show All opens the complete list; only that full list has a Search button, opening a dedicated scoped search page. Library overview no longer shows search. Suggestions also uses a search button leading to its own search page. Publisher metadata cell is a working Visit Publisher link.

Latest steering incorporated: global Search uses a coalesced combined index across both suggested and user-added libraries, with Browse All Apps and per-row Get/Open/progress/cancel. Root catalog rows no longer nest buttons in NavigationLinks. Apps Refresh toolbar removed. Settings explains free-account seven-day renewal and actual expiry; it distinguishes container apps from separate installs. Existing UIKit app banner now has single-tap product navigation requiring double-tap settings to fail first; explicit Open and long-press menus remain.

Tab transitions now use a directional UIKit slide animator via a delegate that forwards other methods to SwiftUI's original delegate; Reduce Motion returns the native transition. Single-recognizer/root-only/nested-scroll exclusions retained.

New model checks PASS for combined discovery/subscribed search, no implicit subscriptions, and per-library isolation. Need simulator/device visual checks and cache/metadata fixture review before final packaging. Installed phone remains rc.3/build102. No new IPA has been installed from this pass. Account/pairing/guest runtime qualification remains deferred at user request.


## November 7 extended refinement checkpoint

Latest user requests incorporated into source: lowercase iPAStore visible brand; full iOS Hub snapshot (87 original entries, merged by canonical URL with curated libraries), MIT attribution, 77 additional bundled publisher icons and a library-symbol fallback; marketplace-only editions explicitly gated. Add stays in Suggestions; Remove is immediate. Library metadata is Apps/Web/Developer, fixed 92pt strip and at most three developer lines. No library sharing or overview search. Full collection search expands to a focused field. Category headings use chevrons.

Today editorial artwork/fade now uses the real library header if available, otherwise its icon and matching colors; only that library feeds Worth Exploring. View Library Apps opens its complete list; bottom CTA opens Suggestions. Product pages have solid action pills and scrolled icon/action headers, centered constrained content, and measured More/Less release notes. List buttons use gray/accent pills. Successful installs/imports create local download records; app views create separate recent records, 3/page up to 15, with full searchable/sortable history. Appearance contains system/light/dark, arbitrary accent color and presets, five typography choices including licensed Monocraft, bold text, and true Light/Midnight alternate icons. Discord help link added.

New interactive signing scene hosts the existing isolated signing UI without reexecuting the host; Done completes only the child extension. Headless XPC worker stays separate. A small plist conveys readiness flags only; account secrets retain existing keychain storage. This path compiles but has not yet been installed/qualified on the phone. No account setup requested; the user's deferral remains active. Private backend rebuilt with the visible name/accent; upstream checkout unchanged and no upstream contribution posted.

Validation so far: simulator preview compile PASS, iPhone compile PASS before latest resource/history split; production release checks including new history invariants PASS. CUA verified appearance navigation, pixel font, accent changes, alternate-icon list, real App Store Today/editorial/product-header behavior on unlocked physical phone. New phone payload is not installed yet; latest phone remains rc.3/build102. Found new resources absent from native target during inspection; explicit target resource entries added before final rebuild. Need final compile, simulator interactions, package checks, approval and phone navigation verification.


## Final build 103 package checkpoint

Native engine and preview compile PASS. Matching private signing component compile PASS. Production catalog/compatibility/renewal/history/atomic replacement checks PASS. Final candidate archive CRC, deep/strict ad-hoc signatures, required extensions, aligned build 103 metadata, 128 keychain groups, native bridge selectors, 87-entry directory, Monocraft/license resources and alternate-icon declarations PASS. Final info strips share a scaled 76pt base height; developer is at most three lines. View is the single featured-library action for the complete app list; Take a closer look opens its details. No extra View Library Apps button remains.

Saved exact candidate: outputs/IPAStore-builds/iPAStore-1.0.0-rc.4-build103.ipa
SHA256: 3d62a422f9fc45b0ab86aad21860c70e07b1f3826bfcaf6e2094af73c3a14ede
Manifest and Validation/candidate-checks-1.0.0-rc.4.json accompany it. An earlier rc.4 staging package had stale build 102 metadata and was moved out of outputs into work/refinement/superseded-build102.*; do not install it.

Simulator verification now PASS for compact Suggestions; Add staying in Suggestions; Developer/Web cells; native collection search with automatic keyboard focus and no separate simultaneous magnifier; recent apps and Browse All Apps; horizontal directional tab swipe; product gray/solid action variants; product scrolled icon/Get replacing Share; real Delta More/Less expansion/collapse and no toggle for short iSH notes. The selected accent now explicitly colors More/Less. iOS 27 uses a SwiftUI root without UITabBarController, so gestures attach once to the window and preserve touch-origin movement before pan recognition; native tab-controller animation remains for systems that expose one. Reduce Motion is respected.

Physical installation approval requested for this exact candidate. No build 103 installation attempted before approval. Latest installed baseline remains rc.3/build102 until device inventory confirms otherwise. After approval: install via existing iloader session, verify version and launch, then open/Done the interactive signing scene and check host continuity. Do not complete account/pairing/VPN setup or actual IPA/renewal-cycle tests; those remain deferred by the user.


User explicitly approved “Install build 103.” iloader’s saved account session authenticated successfully. Selected the exact iPAStore-1.0.0-rc.4-build103.ipa (SHA256 verified above) through its native Import IPA picker. iloader now shows Installing App / Sign & Install App. Do not report installed until completion, device version and launch are verified. No signing-account/pairing setup inside iPAStore has been performed.


## Physical build 103 outcome

User approval received for the exact final candidate. iloader reported Operation completed. Device inventory confirms iPAStore 1.0.0/build103, and process launch succeeded. The actual phone displayed the new dark Today/library hero, native Settings and actual provisioning expiry. Signing Setup opened in the hosted child scene; Done returned directly to the same Signing & Refresh page and preserved scroll position. Main host process continuity was confirmed after Done. No account, pairing file or VPN setup was performed. Those and real IPA installation/launch/renewal-cycle tests remain deferred. See Validation/device-checks-1.0.0-rc.4.json.

Final downloadable file: outputs/IPAStore-builds/iPAStore-1.0.0-rc.4-build103.ipa. SHA256 remains 3d62a422f9fc45b0ab86aad21860c70e07b1f3826bfcaf6e2094af73c3a14ede. No user identifiers, credentials or pairing files are included in delivered validation records. Device Hub keyboard capture remains Off.


## Late handoff-path audit — do not finish yet

Build 103 is installed and navigation/process continuity PASS, but source review found a readiness-file path mismatch: child writes Documents/IPAStoreSetupStatus.plist within service HOME (host Documents/SideStore), while host reads host Documents/SideStore/IPAStoreSetupStatus.plist. Expected child document path is host Documents/SideStore/Documents/IPAStoreSetupStatus.plist. Probing only this non-secret readiness file via devicectl. Fix host to read correct path (with legacy fallback), increment build104, compile/package/verify new candidate, then request action-time installation approval for that exact new build. User informed of handoff mismatch; signing setup still deferred, no credentials/pairing imported. Build103 should not be represented as the final finished deliverable until this known bug is repaired.


Handoff-path probe confirmed the real file exists at host Documents/SideStore/Documents/IPAStoreSetupStatus.plist. New pure-Foundation IPASigningSetupHandoff reads that path first, supports the legacy path, whitelists readiness fields, bounds reads and consumes once. Production checks for true flags/date, secret-field exclusion, repeated reads, old path, malformed and oversized data PASS. Engine build104 is running. UI remains the verified build103 layout; the only new functional change is the handoff repair. Final candidate will be rc.5/build104 and needs exact-payload checks and action-time installation approval.


## Corrected rc.5/build104 ready — installation approval pending

Engine build104 and production checks PASS. Packaged exact candidate outputs/IPAStore-builds/iPAStore-1.0.0-rc.5-build104.ipa. SHA256 f6a915bcb8fc4dda3b1813736bb9ba35a80baddbbb73d71c1e5ef314fa78410b. Exact-payload verification PASS for build104 metadata, archive CRC, deep/strict ad-hoc signatures, extension version alignment, 128 keychain groups, native worker markers, resource directory/font/licenses and icon declarations.

Asked user for action-time approval to replace build103 with the corrected build104; do not install before that reply. Their previous “Install build103” does not cover this different payload under the computer-use rule. iloader is signed in and connected, with old operation-complete modal likely still present. Once approved, import the rc.5/build104 file, wait for completion, verify app inventory/launch, open Signing & Refresh (consumes the old physical readiness file), open/Done Signing Setup again, verify the actual child status file is consumed and main host process stays running. Do not complete credentials/pairing/VPN or guest installation/renewal-cycle tests (user deferred).


User explicitly approved “Install corrected build104.” Selected the verified rc.5/build104 file in iloader and started Sign & Install App. Installation is in progress. After completion verify inventory104 and launch, then reopen/Done Signing Setup and confirm child readiness file is consumed and host PID remains unchanged. No credentials/pairing/VPN setup is authorized now; preserve the user’s deferral.


## Finished refinement — final installed candidate rc.5/build104

Explicit approval received and exact verified rc.5/build104 installed through iloader. Inventory104 and launch PASS. Opened Signing & Refresh and the hosted Signing Setup on the phone, then tapped Done. Normal return and same main host process PASS. Actual child Documents directory listing succeeded with zero matching handoff files after Done, confirming consumption; this fixes the path mismatch proven on build103. No account credentials, pairing file, VPN setup, guest installation or actual renewal-cycle test was performed. Those remain deferred at the user’s request.

Deliver final IPA rc.5/build104 (f6a915bcb8fc4dda3b1813736bb9ba35a80baddbbb73d71c1e5ef314fa78410b), not rc.4/build103. Summarize UI/customization/directory/history changes, successful install and setup navigation/handoff verification, and the deferred runtime qualification. Full details: Release1/BUILD104.md and REVIEW.md. No more work is pending for this authorized refinement; full release qualification still requires the deferred setup/runtime tests. Device Hub keyboard capture remains Off; user’s theme and existing app data retained.
