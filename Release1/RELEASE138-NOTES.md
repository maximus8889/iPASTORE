# iPAStore update138

- Search uses a native search field contained in its own page. App pages retain a single floating Back button and Share/Open at their normal height; typed query/results survive Back. This layout/query behavior was verified on137.
- Product pages enable UIKit’s existing native edge-pop recognizer with a scoped delegate. Native interactive slide/cancel animation and recognizer targets are retained. Begin is limited to the current visible top product, more than one stack item, no active navigation transition/presentation and leading horizontal motion. Other delegate behavior and previous state restore on leaving. No global navigation/tab delegate or full-content gesture changes.138 phone checks pending.
- Includes soft-lift/crisp-settle launch vibration and native success haptic with original quiet two-note glass tone. Actual successful install/certificate/free renewal hooks only; simultaneous successes coalesce, stale launch tails cancel and preferences/background state are respected. Duplicate install/signing vibrations removed; library-added haptic respects preference without extra sound.
- Appearance offers independent sound/haptic switches and separate opening/success previews. User approved sound previews on137. No audio-session/permission changes.

Device/preview builds, swipe policy, sealed CRC/signature/version/worker and packaged sound checks pass.137 feedback scheduling and135 catalog model regression checks remain applicable to unchanged source.138 physical swipe/cancellation checks pending. No new downloads/accounts/signing performed.

SHA256: `2239433fe3da4eab8de7c949a46b5184b1a5698be3ec3ad3ecf13129e5970302`
