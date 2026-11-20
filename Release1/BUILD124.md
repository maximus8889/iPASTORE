# Native swipe follow-up · build124 installed and verified

Inherits123 motion polish and122 performance.123 exact candidate installed with approval; native held/cancel check passed but rapid follow-up failed to settle. Preserve the failing result; do not report123 motion ready.

Corrections:
- Use the native UITab selectedTab identity as the source of truth on iOS18+, including initialization, current selection, cancellation synchronization, delegate publishing and gesture target selection. SDK explicitly states related legacy viewControllers APIs are not used once tabs are set. The old legacy selectedIndex comparison could skip restoring native selection after a cancel.
- Buffer initial progress/end until the main turn after UIKit attaches the interactive transition; a flick can finish in the same call stack as native tab selection.
- Diagnostic now reports the stage, native index/context state and progress on a settling failure; checks compare native tab identity too.

Sources changed: IPATabSwipe.swift, Preview/PolishChecks.swift, build numbers124. Backup123 pager in work/motion124/baseline. Device/preview builds running. No124 IPA or install approval yet. Next package/verify, request exact candidate approval, install and rerun --verify-motion plus visual checks.123 remains last installed; normal relaunch without diagnostics has been requested. Do not claim the correction verified until native checks pass.

Sealed124 candidate:
- Device Release and preview builds PASS. Foundation motion policy and all122startup/refresh/signing models are unchanged from123's passing suite; native checks need rerun.
- IPA:outputs/IPAStore-builds/iPAStore-1.0.0-rc.25-build124.ipa
- SHA256:4634a0abe96f02f53949295ccd42a9a411571abf60ce4ff3f25fcc8e9f5a7e1c
- Strict report:Validation/candidate-checks-1.0.0-rc.25.json
-123 was normally relaunched after its failing test.124 awaits exact-candidate approval, then installation/version confirmation, --verify-motion/report read, visual checks and normal relaunch. No124 phone testing yet. Do not mark the animation task complete until native checks pass or report concrete remaining blockers accurately.


Installed/native results:
- User explicitly approved124 installation/testing. iloader refreshed USB availability, selected the exact sealed rc.25build124 candidate and reported Operation completed / Sign & Install App. Independent device inventory confirms iPAStore1.0.0build124.
- Launched --verify-motion with the development device API. Native report PASS: held adjacent-page visibility and cancel; six immediate/rapid reversals and buffered completions; all eight boundaries across the five tabs including Search; Reduce Motion commit/cancel. Held target offset216.15pt with width393pt at45%progress matches the expected55%remaining displacement. All settled roots had identity transforms/full opacity, and native/app selection stayed synchronized. Report:Validation/native-motion-124.json (raw report also in work/motion124/phone-motion-checks.json).
- Relaunched normally without diagnostic args. Device Hub visual checks observed actual forward/reverse Today↔Stores transitions with both pages visible during motion and correct settled selection. Native tab taps also worked after nested product navigation.
- Today cached artwork/app row loaded. View button/row-link navigation to the one-app Mangayomi library and product page worked; native zoom/push transitions and Get/artwork/header controls remained present. More expanded the release text. No crashes or stuck controls observed during these checks.
- Opened Appearance; temporarily selected yellow and restored the original purple preset. Preview/tab accents and selection feedback updated. System display/font and Bold Text settings were kept. Existing native Picker value labels retained purple during the temporary yellow state; record as a theme-refresh follow-up, not a verified fix in this motion update.
- No IPA downloads, app removals, guest launches, source changes, signing/account changes or cache erasure. No actual download completion/Open launch or app-icon switch was performed; those state animations are compiled/reviewed, not end-to-end exercised here. Capture Keyboard stayed off. Normal app left on Appearance with original purple restored; synthetic window removed. No private phone-screen captures saved in the project.

This completes the bounded animation update. All local checks and native motion tests pass; visual navigation checks complete. No universal frame-rate/zero-glitch or subjective best-animation guarantee is claimed. Continue from124 source/package;123's failure stays recorded as superseded.
