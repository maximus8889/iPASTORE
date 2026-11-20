# iPAStore update135

- Product destinations explicitly suppress the native Back item retained by active Search. The app page keeps its floating Back/Share/Open controls and hidden navigation toolbar. Native edge swipe and Search query restoration need phone verification.
- Launch vibration is a brief soft-lift/crisp-settle pair, scheduled without delaying launch. Repeated launches cancel the old second tap; backgrounding or disabling haptics prevents delayed feedback.
- Successful installation, accepted certificate verification and successful renewal use a native confirmation haptic and an original quiet two-note glass-like tone. Nearby successes coalesce instead of stacking sounds. Removed duplicate row-driven install vibration.
- Existing sound/vibration preferences are preserved. Appearance now has separate App Opening and Success previews, with independent sound/haptic controls. System sound behavior is retained; no audio-session or notification permission changes.

Device Release/preview compilation, release regression checks, feedback scheduling/cancellation/settings checks and source/packaged audio validation pass. Sealed IPA CRC/deep strict signatures/worker/version checks pass. Physical Search/navigation and feedback perception pending; no new downloads/account changes/signing operations tested.

SHA256: `76f4b2d114549860dccaa6627ba4f1ba66a7241fb5ea3493da6626632d34d48d`

Phone follow-up:135 installed. Duplicate Back removed, but user confirms Back/Share remain offset downward.136 corrects the retained Search navigation-row layout;135 is not the final accepted navigation fix. Feedback perception and edge swipe have not yet been confirmed.
