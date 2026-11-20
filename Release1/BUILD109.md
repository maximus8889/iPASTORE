# Launch and return navigation · active candidate109

User requested smoother Open animation and a lower-half double-tap to reveal a close/return button. Keep108 archive fix untouched. Limit scope to apps running inside iPAStore; separately installed Home Screen apps cannot receive this container control.

Implementation: central guest handoff uses0.2s root-view zoom/fade before existing restart, duplicate handoffs guarded, guest window first appearance uses0.32s zoom/fade. Reduce Motion skips zoom. Double-tap is observed after UIWindow normal event dispatch, with no tap cancellation or delay. One-finger ended tapCount2 in lower half reveals native material pill “Close & Return to iPAStore”, auto-dismiss6seconds; repeat gesture dismisses. VoiceOver double-taps reserved for accessibility. Closing preserves installed files and data; current unsaved guest state ends.

Guest hook is installed explicitly by bootstrap for regular guests, including apps with optional tweak loader disabled, and excludes signing setup. Normal-process return sets the existing ui selection and uses normal host relaunch. Hosted LiveProcess return carries a per-scene random token; host accepts only its own live process/token and invokes existing close paths. Native window close notification uses exact validated PID. Unrecognized URLs cannot close arbitrary processes.

Building109. Physical launch/gesture/return still need testing; do not claim an OS process-restart gap is eliminated. No new physical candidate installed yet. Baseline108 confirmed working downloads by user.

## Candidate sealed
Artifact: outputs/IPAStore-builds/iPAStore-1.0.0-rc.10-build109.ipa
SHA256:f8d787fe86fe53725fafc0ef91a749092a975c565ccca094bc6d8b1794b1b95f
Device Xcode build PASS; package integrity, nested signatures,128keychain groups, worker selectors and extension-version checks PASS. Packaged shared binary contains gesture/return control and handoff selectors. User approved109; installing through iloader. Runtime gesture/return remains unverified until phone test.108 extraction code untouched.

## Physical result
iloader installation completed. Device inventory independently confirms109. User directly tested the lower-half double-tap and button action, answering “Yes, both work”. Gesture/return passes by direct user confirmation. Animation is implemented, with no separate subjective-quality confirmation. Do not claim separate Home Screen app control or a universally seamless OS restart. No further work requested.
