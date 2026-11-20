# Paging stability and on-device verification · build118 in progress

User reversed the previous testing preference and explicitly authorized iPhone testing. Latest steering: swiping must follow TikTok's continuous finger tracking. Build117 currently installed. User has not approved installation of118 yet; finish package then request action-time approval for install and testing.

Physical baseline117 reproduction through Device Hub:
- Opened TikTok for reference; taps work but remote drag/scroll events do not reliably reproduce actual finger swipes. Do not claim measured TikTok motion or held finger test from these inputs.
- Opened iPAStore117, tapped Stores. Native tab highlight changed to Stores, but Today remained displayed, shifted/clipped on the left. Tapping Apps afterward still left Today displayed; View action stayed absent. This is a real page/controller selection/layout failure, not just a cosmetic timing issue.
- CUA reproduction phase completed with required summary. No app downloads, account/certificate actions or game launches performed.

118 implementation:
- Replace moving native tab-controller-owned hosting views with a permanent paging UIScrollView in its own content controller. Five native tabs select lightweight empty controllers. The retained hosting roots belong only to the permanent pager and never move between superviews while swiping or selecting tabs.
- Native continuous horizontal scrolling supplies tracking/hold/reversal/deceleration. Delegate target aligns the nearest page. Native tab taps animate content offset; rapid requests retarget the same scroll view. Canceled pans, background and rotation recover selection and control visibility.
- Preserve native tab chrome, horizontal shelf priority, edge Back, vertical scroll, text/slider/switch gestures. Three nearby pages prepare lazily and remain attached after loading. No per-frame SwiftUI page movement or tree replacement.
- Page-safe bottom inset follows the actual laid-out tab bar; zero/unlaid-out bar frames cannot become a full-screen bottom inset. Horizontal safe-area clipping is ignored by page roots to keep offscreen widths stable.
- Existing control fade state, press/download/search animations remain. Controls restore after scrolling actually settles.
- Settings Help has Check Navigation. It runs the actual mounted pager on the phone across tab changes, four held/canceled distances, origin reversal, rapid selection and interruption. Bounded local report iPAStoreNavigationChecks.json contains only indices, geometry, status and UIKit class names; no credentials/pairing data/content. Shared preview integration invokes the same checks. This verifies mounted layout and state; it does not substitute for physical finger feel/input routing.

First corrected device/preview builds compiled. Final bounds/cancellation/source-policy improvements compiling next. Pure nearest-index tests added for threshold, edges and invalid geometry. Package, physical checks and results pending. Do not claim fixed or verified until phone results observed.

Build118 candidate complete: final device Release and preview builds PASS. Release model checks PASS (30,000-record prepared query29ms), including new nearest-index clamping/threshold/invalid-geometry cases. Strict archive/signature/128-keychain-group/worker/extension checks PASS. Artifact outputs/IPAStore-builds/iPAStore-1.0.0-rc.19-build118.ipa SHA256 5ed5e6fc07c3bc8423ec587ad98d1c9dac63c4a0148445b470008bb764817f16. Installation and phone-test approval requested via async question. Build117 remains installed. Once approved install118 via iloader, confirm version, open via Device Hub, repeat baseline taps, run Settings → Help & Community → Check Navigation, retrieve the bounded Documents/iPAStoreNavigationChecks.json if needed and record actual results. Do not claim device verification before observing it.

User explicitly approved install and test of build118. iloader selected exact rc.19-build118 and is running Sign & Install App. Planned physical checks are navigation only (no downloads, account changes or guest app launches).

USER CANCELED118 TEST WORK AND REQUESTED116 ROLLBACK (2026-11-09). iloader had reported successful118 installation, but no118 navigation test results were collected before the user changed direction. Do not resume118 tests or use it as the baseline. Original116 has now been reinstalled and independently inventory-confirmed. Active source restored to116; see ACTIVE_BASELINE.md.
