# Motion polish · build123 in progress

Base: installed122. This user's new animation request explicitly authorizes revisiting tab motion; do not restore the broken117/118 reparenting/pager experiments. Preserve122 performance and119 refresh/signing/archive safeguards. Phone testing remains authorized; a sealed new candidate needs per-candidate installation confirmation.

Audit: native UITabBarController remains the sole owner. Current separate noninteractive UIView.animate and interactive custom-property-animator paths can settle differently; investigate unified interruptible animator, progress buffering, completion/cancellation and selection recovery. Polish shared button presses and Get/progress/Open state transitions; library Add feedback; artwork fades; expansion and compact-header changes. Use short bounded motion and Reduce Motion alternatives; do not animate every catalog row/progress byte or delay navigation/open actions for decoration.

No simulator runtimes installed (verified outside sandbox). Preview compile and Foundation/model tests are available; actual UIKit progress/settle checks should run on the iPhone through a bounded diagnostic harness if needed. Backups: work/motion123/baseline. No123 candidate/approval yet. Implementation/checks pending.


Implementation complete; candidate builds running:
- Native UITabBarController and retained hosting roots remain sole owners. No117/118 root-reparenting/pager experiments restored. Native UITab selection is used on iOS18+, with controller containment lookup to identify wrapped roots.
- One interruptible UIViewPropertyAnimator serves native tap/swipe transitions. UIPercentDrivenInteractiveTransition buffers very fast progress/end events. Finger progress is linear; release/cancel uses ease-out with bounded180–300ms remaining duration. New taps are rejected until a held/settling swipe completes. Reduce Motion defers a drag's selection until release and uses a short opacity transition.
- Shared short press/release curves for Get/Open/View/Add, row links, progress controls, search cancellation, icon and color choices. Get/progress/Open and Add/Added use bounded fade/scale transitions with stable button width. Product-only completion feedback avoids repeated success haptics from mirrored catalog rows; a source-add success feedback is emitted once in its action.
- Artwork fades, expandable text, compact product-header transitions, collection-search reveal, swatch/icon selection and Apps installation-row changes polished. Reduce Motion suppresses spatial/geometry changes; no new continuous timers/shimmer, delayed app launching, per-byte text effects or mass catalog-row animation.
- Opt-in --verify-motion creates a temporary native window with five synthetic pages and writes only numeric/status results to Library/Caches/IPAMotionChecks.json. No production accounts, downloads or catalog settings are touched by the harness. It checks native held partial visibility, cancellation, six rapid reversals/early-end events, eight boundaries including Search, tap rejection during tracking, identity/opacity cleanup, native/app selection consistency and Reduce Motion commit/cancel. It is not a substitute for real finger input; follow with bounded visual checks. Normal launches never run the harness.

Local release/model suite PASS: existing startup/cache/refresh/signing/replacement checks plus finite/clamped gesture input and198release/cancel settling cases. Initial compilation caught an invalid read-only override of UIKit's writable wantsInteractiveStart; corrected by assigning in init. Subsequent device/preview builds PASS. Final feedback refinement build still pending. No123 IPA, approval, install or phone test yet. Do not claim the swipe fix physically verified. Read Apple's official custom tab transition/interactive-controller docs and SDK header for selectedTab/shouldSelectTab; no external source code copied.


Sealed candidate ready:
- Final device Release/preview builds PASS (device-candidate.log / preview-candidate.log).
- Release/model suite PASS, including startup/cache/refresh, categories, recent/download persistence, compatibility/signing/replacement and motion input/settling cases. The model checks do not prove UIKit held-page rendering.
- Strict package checks PASS: CRC, deep signatures,128keychain groups, native worker selectors and aligned extension versions.
- IPA: outputs/IPAStore-builds/iPAStore-1.0.0-rc.24-build123.ipa
- SHA256:395ff2a39a7d7b2f95e7b422da0441cb3bcdbfc3c250c3a2079ee91bcf69ee1a
- Report:Validation/candidate-checks-1.0.0-rc.24.json

Await exact-candidate install/test approval.122 is the last confirmed installed build. Next: install123 through iloader, confirm version, launch with --verify-motion through the development device API, read Library/Caches/IPAMotionChecks.json (only this diagnostic report; no account/pairing data), inspect actual tap/swipe/button/expansion/artwork behavior, then normal relaunch without diagnostic args. If native checks fail, investigate and fix; do not claim swipe success based on compile/model results. No downloads/account changes or guest launches needed. File/progress saved for continuation.

Device outcome: user approved and iloader installed exact123 package; device inventory confirms1.0.0build123. The --verify-motion native diagnostic returned FAIL: held partial page visibility and cancellation PASS (216.15pt offset of393pt width), but the next rapid buffered finish failed to settle. Report work/motion123/phone-motion-checks.json. Do not claim native swipe success. Normal relaunch without diagnostic args requested. No downloads/accounts/guest launches touched.124 correction in progress;123 is installed but has a known gesture failure.

Superseded: corrected124 installed and passed the full native motion suite and bounded visual checks. See BUILD124.md. Continue124, not the failing123 pager.
