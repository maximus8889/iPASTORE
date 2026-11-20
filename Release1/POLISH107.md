# Compact layout and interaction update — active

Baseline: installed rc.7/build106. Keep existing apps, sources, appearance and signing state. Reliability was added to the scope by the user; real account/pairing/renewal and guest launch remain unqualified until phone testing.

- [ ] Remove Suggestions search button/page.
- [ ] Immediate tint everywhere, including Settings installation picker after returning; native adaptive default blue.
- [ ] Compact Stores Sort menu consistent with Apps; short wording/native menu type sizes.
- [ ] Product artwork reaches top behind controls; no hard navbar boundary; real pull-down stretch.
- [ ] Smooth compact icon/Get/Open fade with no surrounding toolbar border and no threshold lag.
- [ ] One source-library redirect; remove duplicate developer/library links.
- [ ] Versions beside primary Get/Open; remove standalone version section.
- [ ] No divider after final metric; fewer section rules.
- [ ] Compatibility value: icon + number, no iOS prefix. Notice inside Information.
- [ ] Compact library Apps/Web/Developer strip; bounded long names.
- [ ] Remove library-page Remove action; preserve immediate Stores context-menu removal.
- [ ] Real finger-following tab transition with cancel/settle and Reduce Motion support.
- [ ] Short, single-line Sign Now description with consistent row size.

Implementation/validation/install checkpoint will be updated below. No subagents. Build complete and review exact candidate before asking for its phone installation approval.

## Implementation checkpoint
- Native UITabBarController now owns five retained SwiftUI hosts and native Search tab; UIKit's interactive transition delegate is available on all supported iOS versions. Snapshot-after-gesture fallback removed.
- First tests caught a real problem: default percent-driven updates could be lost around context startup. Replaced that driver with a public UIViewPropertyAnimator-backed interactive controller that queues progress/finish/cancel until context creation. Runtime tests require the adjacent page to be visibly between its initial/final positions, then test cancel/commit and binding agreement. Current iteration under test; do not claim it passes yet.
- Product top edge uses safe-area extension and hidden navbar background over artwork. Compact controls stay mounted and fade from actual header visibility; iOS26+ compact primary action hides shared toolbar chrome.
- Versions is beside Get/Open, provenance is one library row, final metric no longer has trailing rule, compatibility number/icon values and notice live in Information. Section rules reduced.
- Suggestions search page removed; library removal remains in Stores context menu. Library strip58scaled points, three bounded columns; Stores menu labels shortened and native typography aligned with Apps.
- Default blue maps legacy007AFF and new systemBlue preference to native UIColor.systemBlue; explicit theme applied per native host, Settings picker rebuilt only when accent changes. Sign Now subtitle shortened to one line. Backend's tint resolver updated consistently; matching derivative hash updated, service rebuild still needed.
- Simulator compile and Foundation/paging policy checks pass. No new physical build/package/install yet. Baseline on phone remains106; signing/account tests remain outside this pass.

## November8 user steering — install/setup reliability now takes priority
User reports .p12 selected during Signing Setup does nothing, Verify Connection/account grayed out, confusing current-install expiry, all attempted downloads reported Invalid IPA, slow/unanimated progress. Wants real progress, installing rows in Apps, pause/resume/cancel/remove and ability to start another download. Clarification: file was p12; failures described as any app, no exact library/app supplied. Preserve entire visual scope above.

Plan: recognize p12 selected in pairing flow and securely hand it to native host certificate/password sheet; show why pairing/connection/account steps need different requirements, with actionable buttons instead of silently disabled controls. Clarify expiry is the current Mac-installed provisioning signature, not proof account setup completed. Investigate archive path with real compressed archives/iOS runtime, not only tiny stored test fixtures. Replace transfer with explicit delegate-owned file lifecycle and throttled byte progress; show activity rows and support controlled pause/resume/cancel with serialized signing/install work.

Interactive transition runtime integration PASSED after custom driver: actual 45% transition had adjacent page at221.1 points of402 width; cancellation and commit kept native/model selection aligned; native tint and adaptive blue passed. Preview still needs final top-artwork/header visuals, reverse/edge swipe checks and final build qualification. No new physical candidate yet; phone baseline106. No signing/pairing/account success claimed.

## Reliability implementation checkpoint
- A p12/pfx selected in free-account pairing is now copied into a private bounded handoff, then opens host certificate/password import. The handoff rejects symlinks, consumes the owned copy once and preserves the original. Pairing error presentation waits for file-picker dismissal. Verify/account buttons give missing-step guidance instead of unexplained disabling.
- Current-install expiry explicitly identifies the existing signature supplied by the installer; it is not a claim account setup completed.
- Explicit delegate-owned downloads move the file before URLSession removes it. Real byte updates throttled to10Hz; missing length remains indeterminate. Per-app jobs appear in Apps with pause/resume/cancel/help/remove. Transfers run concurrently; extraction/signing/atomic commit serialize. Paused completion cannot advance to installation until Resume. Pause applies during the running app; no background/relaunch persistence promised.
- GET provides a Preparing indicator before checks; parsed PKCS12 dates cache only for identical credential bytes/password, so repeated view construction does not redo expensive crypto. Certificate and archive enforcement retained.
- Added separate HTML/non-ZIP and HTTP failure guidance; extractor now returns safe stage diagnostics instead of an opaque Invalid IPA.
- Actual transfer regression PASS: byte equality, temporary-file lifetime, pause/resume, second transfer while paused, cancellation, unknown length, HTTP error. Release/pairing handoff regression PASS. Production extractor PASS on macOS including a52MB packaged IPA, explicit/late directories, deflate, streaming descriptors/ZIP64 and hostile paths/links.
- User did not identify exact failed app/library. The reported universal iPhone Invalid IPA root cause has NOT been reproduced; diagnostics and the iOS runtime check must resolve it. Do not claim every app is fixed or signing/launch succeeds.
- iOS simulator installation/launch was unusually slow; older report was stale and lacked new archive result. Restarting to execute actual new check. Device107 and service final builds in progress; no new physical installation yet.

## Candidate107 sealed and approved
Artifact: ../IPAStore-builds/iPAStore-1.0.0-rc.8-build107.ipa
SHA256:9a8fb7b7d23494cee275f4fd70ea9ce92cbd8eb5986361cdb12600fea81b2bb1
All three final Xcode builds PASS. Candidate checks PASS, including strict signature/archive CRC/128keychain groups/workerselectors/extension versions. No real signing identity embedded.
Latest iOS runtime report PASS: real52MB IPA extraction, finger-following mid-drag page transform, cancel, commit, reverse, native live tint/adaptiveblue. A cancel-selection mismatch on modern native tabs was found and fixed with explicit selection reconciliation; new report passes. Product screenshot confirms versions next toGet, number-only compatibility, singlelibrary provenance. CUA coordinate drags/wheel did not move the simulator product scroll; pull stretch/compactheader final visual check remains pending.
User explicitly approved install/test107. Beginning iloader saved-account sign-in and physical update. No credential/files copied into outputs.

## User stopped testing — November 8
User said: “u can stop i checked it it works”. Stop further testing/build/install actions. Build107 remains installed. Physical certificate verification was independently observed successful: iOS accepted a test signature. User reports the update works; do not turn that into a claim that every download/runtime, free-account pairing, or renewal was independently verified. No additional library app installation was started. Last phone screen was Stores.

Follow-up108: user reported downloads still failed. Physical Help & Recovery isolated “Creating app files: Cannot extract through symlink app staging/Payload” (iSH/DolphiniOS failed rows). Replaced the disk writer with descriptor-anchored no-follow/exclusive operations, preserving archive guards. Tests/device/preview/package checks pass.108 installed with explicit approval; user directly confirms downloads work. Details in BUILD108.md. Stop further testing.
