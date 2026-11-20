# iPAStore rc.6 — build 105

Candidate: `iPAStore-1.0.0-rc.6-build105.ipa`

SHA256: `55245ca07e5ed58492d0d81d89add14b959ee53020e8d8cacd53ad82e5fa279b`

## Reliability changes

The signing page called an optional scene-update callback without checking that its delegate implements it. Two iPAStore-only crash reports show the resulting unrecognized-selector abort. Build 105 guards that callback, corrects child cleanup and reports an unexpected signing-process exit with recovery instructions.

App opening now checks signing readiness before process handoff and verifies that iOS accepts the signed executable. The installer also checks the staged executable before committing an app. Missing signing credentials and an unsuccessful signing callback no longer count as success.

Certificate import and usable signing are separate states. A fresh signed test library must pass iOS library validation before the certificate is marked verified. The check is asynchronous, uses an isolated temporary copy and has a deadline. It does not load that library. Readable, current certificate dates alone do not prove that a certificate is provisioned or accepted by iOS. Revocation or future provisioning changes can still invalidate it.

The setup screen distinguishes Apple Account setup, a supplied certificate, and renewing iPAStore itself. Pairing-file instructions support export and Files import without requiring the Mac installer to recognize iPAStore. Expiry reminders report permission and scheduling problems and handle signatures expiring within 24 hours.

## Interface changes

App pages use publisher banners with screenshot fallbacks, a stretching/fading header, horizontal information, preview galleries, expandable notes, more from a library and related apps. Supplemental Apple listing metadata requires an exact bundle identifier and is attributed separately from the library’s IPA. Unavailable reviews, events and privacy declarations are not invented.

Sort menus include Search on app/history/library collections. Libraries support saved manual arrangement. Apps places Files on the left and Sort on the right. Horizontal shelves reveal the next page. Stremio’s broken icon has an authentic publisher fallback. Appearance applies locally in its own settings page. Newer SwiftUI tab swipes use page snapshots; native tab bars remain in place.

## Validation

- Engine and matching signing-service builds: passed.
- Simulator build: passed.
- Production model checks, including artwork identity, unsafe URL filtering, response bounds and launch-recovery classification: passed.
- Package CRC, strict/deep signatures, 128 requested shared keychain groups, extension versions and native bridge selectors: passed.
- iPhone installation: completed by iloader; exact device inventory confirms build105 and native launch succeeded.
- Real pairing/account connection, certificate acceptance, guest launch and renewal: pending device qualification. Device-control coordinate input fails before delivery; user has been asked for direct certificate/VPN/idle checks. No new host crash report appeared in the narrow post-update filename check.

This is an ad-hoc development IPA. It must be signed/provisioned by the installer. It is not a claim of universal app compatibility or guaranteed background renewal.
