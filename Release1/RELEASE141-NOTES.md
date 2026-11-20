# iPAStore update141

- Restores the pre140 tab coordinator, animator, interaction driver and timing policy exactly. Construction is shared once by production and the native check; no new tab visual/timing changes.
- App pages use one standard visible navigation bar with transparent background: system Back, native Share, and conditional Get/Open plus app icon on scroll. Removes the floating Back overlay, duplicate trailing-action stack, unused custom button style and the entire custom page-gesture proxy/probe mechanism. Native system navigation owns the back transition; no page recognizer/delegate mutation remains.
- Common child pages use one declarative native navigation policy. Search retains the contained native field/query behavior, lowers the large heading in a single content header and tightens its field gap; no duplicate native Search title.
- Preserves approved soft launch/success haptics and glass-like success tone with settings/previews; no sound changes.
- Native checks now wait for foreground, use one production tab factory and tagged reports, and validate real standard stack/recognizer attachment without invalid possible-state pan simulation. Normal runs do not activate diagnostic checks.

Device/preview builds, release model regression, exact tab rollback comparison and sealed CRC/signature/version/worker/audio checks pass.Build 141 is installed and version-confirmed. Fresh on-phone native navigation and restored-tab checks pass, including cancellation and rapid reversals. Actual library/product controls and the lower Search heading were checked visually. The user confirms two repeat actual-page swipes work. Separate Search-route physical swipe and final heading acceptance remain unconfirmed. No new downloads/accounts/signing.

SHA256: `6d410250bf2180a9578d5a38edeb1566e46bb3cbf0166b4dd818d8ffc3ba4ea2`
