# iPAStore update137

- Search’s native field is now contained within the Search page, retaining normal keyboard, clear button, accessibility, query state and existing deferred search. Its navigation-owned search controller no longer adds a native Back row to app pages. Product layout is restored to134 with its floating controls and standard native navigation; no manual offsets or gesture-delegate overrides. Keyboard dismisses when leaving Search or using the keyboard’s Search key.
- Launch haptic is a brief soft lift followed by a lighter crisp settle. Rapid repeats cancel stale taps; the delayed tap checks foreground and preferences again. No launch-blocking wait or haptic audio-session startup.
- Actual successful install, certificate verification and renewal use native success haptic plus an original quiet two-note glass-like sound. Nearby successes coalesce. Duplicate install/signing view-driven vibrations removed; adding a library respects the vibration preference without adding a sound.
- Appearance retains existing preference values and offers separate opening/success previews with independent sound and haptic switches. System sound behavior retained; no permission or audio-session changes.

Device/preview builds and sealed CRC/signature/version/worker checks pass. Feedback scheduling/cancellation/settings checks and packaged PCM edge/tail/peak checks pass.135 catalog regression suite remains applicable to unchanged models.137 phone checks pending. No new downloads/accounts/signing tests performed.

SHA256: `dfba6da38bf6ba63f155d9dffa0356f9dd6f773ff225a5f17fe69267184c8b7e`
