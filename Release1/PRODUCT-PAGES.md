# Product-page and interaction update — active checkpoint

Baseline: installed iPAStore 1.0.0 rc.5/build104. Final IPA SHA256 f6a915bcb8fc4dda3b1813736bb9ba35a80baddbbb73d71c1e5ef314fa78410b. The latest user request now prioritizes fixing and qualifying signing/pairing/VPN and guest launch; the previous deferral is superseded. Preserve current app data and appearance preferences.

User scope for next update:
- Study actual App Store product pages on connected iPhone: artwork, stretchy scrolling/fades, compact header, icon/action alignment, horizontal info strip, separators, corner radii and spacing. Match familiar native geometry without inventing unavailable ratings/events/privacy declarations.
- Prefer a genuine app/game banner; automatically resolve trustworthy matching artwork where feasible. Fall back to the center of supplied screenshots when no banner exists. Repair broken Stremio library/app icons and other broken image paths with verified alternatives. Never match artwork solely by a similar display name.
- Rich information where publishers supply it; more from same developer/library and similar apps across libraries. No fabricated reviews, privacy claims or events.
- Three-row shelves should reveal part of the next page at the right edge.
- One consistent arrows Sort menu including Search, in Downloaded/Recent, full library/category lists, Apps, Stores and other relevant scoped lists. Avoid a second separate magnifier or abrupt navigation/field animation. Preserve custom manual app arrangement; add persistent library ordering/arrangement.
- Apps Files left, Sort arrows right, search inside Sort. Stores top-right Sort/search/arrange; keep Add Library available in a sensible place.
- Appearance changes update that page immediately; remove fixed blue from signing/refresh/verification/local-connection icons. Preserve semantic error/warning colors.
- Smooth real slide transitions on swipes (current window-layer transition may be snapping on iOS27). Reduce Motion respected; do not steal horizontal shelf or back gestures.
- Investigate and remove installed-app product-opening delay. Current single tap waits for double-tap failure. Keep settings accessible and resolve this deliberately. Optimize navigation/derived data/artwork; do not promise literal zero latency.

Status: inspection starting. No source changes or new installation yet for this pass. Keep this checkpoint current with findings, exact candidate/version/hash, validation and remaining work. No subagents unless requested. Build/deploy only a reviewable checked candidate; ask at action time for any new local phone installation as required by the computer-use policy.


## November 8 steering — stability comes first

User reports: installed apps without signing crash on Open; hosted Signing Setup crashes on Open LocalDevVPN and while idle; Verify Connection/account/pairing unavailable; expiry reminder toggle fails; imported p12 says Ready but installs still blocked. Need simpler explicit Free Account vs Certificate paths, meaningful preflight and recovery pages, and real end-to-end qualification. New request asks us to fix setup failures; do not blindly retain the old deferral as a reason to leave them broken. Credentials/p12/passwords must stay private; user enters them directly if required. Preserve full earlier product-page/layout/artwork/sort/search/appearance/latency scope after urgent reliability repairs.

Automatic approval review rejected a broad metadata lookup in systemCrashLogs filtered only “Live”, reasoning that unrelated private diagnostics could be included. Do not bypass. Narrow to verified app process prefix LiveContainer- and helper LiveProcess- if review permits; collect only app-relevant reports. Unaffected source inspection continues.

## Confirmed stability findings and source changes (work in progress)
- Exact iPAStore crash reports identify SIGABRT / unrecognized selector in AppSceneViewController scene-settings callback. Optional delegate method was called without a respondsToSelector guard; signing controller does not implement it. Guard added, delegate made weak, child cleanup corrected. Unexpected signing-scene exit stays on a recovery explanation instead of silently returning.
- LCAppInfo treated missing certificate password as signing success. Non-JIT launch now preflights signing readiness before mutation/restart and checks kernel acceptance of the signed executable. Silent false-with-no-error signing result now fails. Installed-app Open routes structured errors into Help & Recovery.
- Imported p12 date validity no longer means ready. A fresh isolated TestJITLess signature must pass the kernel library check. Verification fingerprint includes actual host provisioning profile. Both password stores are written consistently. Actual app signature is checked after signing in staging, before commit.
- Removed blocking infinite semaphore/fixed shared temp filename from certificate probe; fresh private temp copy, single completion and 30s deadline. No binary loaded by the probe.
- Signing screen now separates Apple Account, own certificate and host renewal. Certificate-only app signing does not require pairing/VPN/account; separate Home Screen installation still requires provisioning. No false promise p12 alone permits arbitrary installation.
- Reminders report denied permission, missing profile, expired signature and scheduling failure; near-expiry reminder schedules promptly; atomic notification replacement.
- Backend pairing precedes connection verification, export/Files guidance does not require iloader recognizing iPAStore. LocalDevVPN URL checked against its official repository; open failure provides manual launch guidance. Incomplete setup steps use chosen tint.
- Appearance destination applies live theme locally. Other design/navigation/artwork/sort requests still pending.
- First compile caught static call qualifier; corrected. Current engine and backend builds are in progress. No new candidate installed yet. Real signing/account/pairing/install qualification still required.

## Product/UI implementation and build status
- Compared actual App Store Today, product header, info strip and sections on connected iPhone. Product UI now has constrained full-width center-crop artwork with pull-down stretch/fade, larger icon, native compact header action, horizontal metadata strip, version notes, screenshot viewer, information rows, more-from-library and category-based cross-library suggestions. Real publisher screenshots remain the primary gallery.
- Added exact-bundle Apple listing lookup with secure artwork filtering, bounded responses, coalescing, rate spacing, positive/negative caching and bounded disk cache. No title-only matching. Matching listing ratings/age/languages are explicitly attributed; no invented events/privacy claims. Real banners still come from publisher headerURL; screenshots are the fallback.
- Library icons try alternate app/publisher candidates. Stremio’s broken 404 icon now has the real already-bundled publisher asset as fallback for library and app. Shared memory previews appear while larger images load.
- Shared Sort menu -> Search field for categories/More Apps, Downloaded/Recent, Apps and Stores. Apps Files left and Sort arrows right. Library manual arrangement persists, Add Address remains in menu. Three-row category/recent shelves now show next-page peek.
- iOS27 swipe fallback uses old/new page snapshots around actual SwiftUI layout, leaving native tab bar stationary; older native tab controller animator retained and Reduce Motion respected. Needs visual verification.
- Removed double-tap failure wait from installed-app single tap; simultaneous double recognizer retained. Needs physical interaction check, with long-press settings still available.
- Engine build105 and matching backend compile passed. Simulator compile passed. Expanded production-model checks passed (exact artwork identity, unsafe URLs/oversized metadata, signature/JIT/missing-library recovery plus existing catalog/archive/renewal/race checks).
- Packaging rc.6/build105 now running. Simulator install/launch session still pending; do not start a second overlapping install. New phone installation has not been requested or performed yet.

Candidate rc.6/build105 packaged and verified. SHA256 55245ca07e5ed58492d0d81d89add14b959ee53020e8d8cacd53ad82e5fa279b. User explicitly approved installation and testing. iloader Import IPA has started signing/installing this exact file; wait for completion before any second attempt. Simulator live Today screen confirms Stremio library and app icons render.

## Physical build105 status / follow-up source changes
- iloader completed the approved build105 install. Exact device inventory confirms bundleVersion105; native device launch succeeded. Physical screenshots confirm existing Flappy Bird and StikNES entries and purple/Monocraft preferences preserved. Today has Stremio artwork.
- CUA coordinate taps now consistently fail before delivery with noWindowsAvailable, while AX host controls/screenshot work. Tried fresh bundle binding, Raise, compact window and runtime reset. No alternate UI-automation bypass used. Asked user to test Verify Certificate, VPN open/return and one-minute idle behavior directly; answers pending.
- Found an additional mode-confusion edge: independent-install preflight sent users with only a p12 back to generic container-signing guidance. Source now has distinct independent-setup explanation and explicit Use Apps in iPAStore recovery button. Native Apps Open pill also corrected to gray fill/accent text (SwiftUI pills already correct). These are source-only follow-ups after sealed105; build105 IPA stays unchanged. Will package a new candidate only after current device feedback is incorporated.

Additional verification: disassembly of archived104 confirms return address0x5c14 is immediately after the optional delegate callback at0x5c10. This establishes the exact crash cause rather than relying on the method name alone. Sanitized evidence saved in Validation/stability-findings-build104.json. Narrow host-crash filename recheck after105 found no new report (this is not a substitute for a complete signing test).

Simulator UI navigation passed: Today -> Entertainment -> Stremio product renders restored icon, screenshot-backed hero, horizontal metadata, notes, gallery, information and related apps. Get with no certificate presents Help & Recovery / Finish Signing Setup before downloading. Source106 further skips obvious login/sign-in screenshots when picking a fallback hero and keeps the Signing settings icon bound to accent color. Phone manual certificate/VPN/idle answers remain pending.

## Ready checkpoint — build106
- Final source106 includes independent-mode recovery, gray/accent UIKit Open pills, certificate-probe-specific errors, host-in-renewal-results safeguard, broken catalog-icon exact-listing fallback, login-screenshot avoidance and compact relative dates.
- Engine106, matching backend and simulator compile all passed. Expanded production checks passed. Derivative hashes match checkout and packaged service contains new renewal safeguard.
- IPA: outputs/IPAStore-builds/iPAStore-1.0.0-rc.7-build106.ipa
- SHA256: 2d8471bf9354e6f4261e069b4aeb51b415b85b6719bfe40138016c48007772ba
- Candidate report: Validation/candidate-checks-1.0.0-rc.7.json. Notes: Release1/BUILD106.md.
- **Build105 still installed. Build106 installation approval is pending. Do not install before approval.** User already approved105 only. iloader account remains signed in; use Import IPA for exact106 candidate if approved. Do not change payload or reuse approval for another build.
- Separate manual phone check questions remain pending: Verify Certificate result; Open LocalDevVPN / return and one-minute idle crash check. Do not invent outcomes or assume time elapsed means success.
- CUA currently selected IPAStore Preview simulator, on Help & Recovery after Stremio Get. Last CUA operation closed with completion_summary Verified product guidance. Runtime binding storefrontHub exists after a reset, points to com.apple.dt.Devices. Physical coordinate taps fail noWindowsAvailable; AX host controls and simulator app elements work. After compaction call rewriteDocumentation before CUA continuation.
- No real Apple Account setup, pairing import/grant, guest launch or renewal completed by us this turn. These remain release gates, not accomplished work. Pairing/account secrets stay out of chat and outputs.


## Installed checkpoint — build106 (latest)
User explicitly approved build106. iloader completed installation of exact rc.7 IPA, native device inventory confirms bundleVersion106, and native launch succeeded. Build106 is now the phone baseline. Last CUA task closed with completion_summary Installed build106. Do not confuse the earlier pending-approval entries with current state.

Validated: engine/backend/simulator compile, production model checks, package CRC/signatures/extension versions/128 groups, matching service source and compiled host-renewal safeguard, exact physical installation and launch. Earlier simulator interaction verified product artwork/metadata/notes/gallery/recommendations and Get -> Help & Recovery gate. Physical105 screenshots confirmed installed-app and appearance preservation;106 follow-up retains that update path.

Still REQUIRED: manual Verify Certificate result; VPN open/return + idle behavior; real pairing/account qualification; legitimate guest install/launch; real host renewal. Existing two user questions about certificate and VPN checks remain unanswered. Do not invent outcomes, test dates or guarantee app compatibility/background renewal. No source changes after sealed106 package. Current source/build/artifact version106, SHA256 2d8471bf9354e6f4261e069b4aeb51b415b85b6719bfe40138016c48007772ba.
