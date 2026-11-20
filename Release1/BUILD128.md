# Signing feedback and app-page polish · build128

Base: installed127. User handles phone tests. No128 installation approval yet. Preserve125 More/Less, latest-release notes, no Preview/description divider,124 pager,122 artwork/network/startup limits and all signing/archive/identity checks. Backups: work/product128/baseline.

Certificate investigation: the import sheet's onDismiss previously called verifyCertificate whenever any saved certificate existed, even after Cancel or a swipe dismissal. The real validator signs a fresh test dylib and asks iOS to check its signature; the installer still gates on certificate digest and validity. Therefore opening/cancelling can verify a previously saved credential; it is not evidence of a certificate-free bypass. No private certificate or account data was inspected.

Changes:
- Add Certificate label/title (also Add confirmation). Import completion is reported only after the .p12/password passes validation and is stored. Closing/cancelling without that callback reloads state but never starts verification. Existing valid credentials are retained. Readiness explicitly describes a verified certificate saved on the phone.
- Both signing buttons use the same progress/success/error feedback: spinner, label/symbol transition, checkmark, success haptic and an outcome popup. Success depends on the existing signing engine's completed result; the native worker already requires a successful host-app renewal. The popup reports the installed profile's actual remaining time/date, never an invented new seven-day timer. Existing local-account/pairing prerequisites and background rules remain.
- Open/Get labels retain intrinsic width; product action priority protects the button from a long release selector. Floating controls reserve symmetric88pt sides. Job status stays bounded140pt.
- Missing/empty/sentinel developer/version/compatibility/age cells are omitted, and zero/negative size is hidden. The library name is no longer substituted for an unknown developer. Information rows also filter empty values. An entirely empty facts strip is omitted. Removed generic compatibility and ratings paragraphs; actual OS bounds, runtime requirements, matching App Store listing and Privacy & Compatibility remain.
- Product icon/banner/previews use transparent waiting space and opacity-only image reveal. Shared image fading no longer wraps geometry changes in an animation. Size callbacks explicitly disable layout animation. An already-loaded primary stays visible when only supplemental fallback URLs arrive. Network/decoded cache/concurrency limits unchanged.
- A fixed16:9 hero slot is present from the initial product layout so a late supplemental banner does not insert above the header. When all artwork is missing or fails, that band stays empty rather than drawing a gray symbol. Preview row reserves380pt to prevent late image ratios shifting the description vertically; individual screenshots preserve actual image ratio and bounded dimensions. Landscape screenshots can leave extra vertical space in that reserved row.

Checks: initial iPhone Release and preview builds PASS; model/release suite PASS including actual seven-day/two-day/missing/expired expiry feedback and absent metadata cases. Exact125 More/Less preference/component block comparison PASS. Final image-retention refinement builds pending. Native visual/signing/cancellation tests have not run; user owns phone testing. No downloads, accounts, signing, certificate import or guest launches performed.

Final iPhone Release and preview builds PASS including the fallback-metadata image-retention refinement. No model inputs changed after the passing model suite. Pager hash unchanged: fe70496b9d7fef66176d2c867f5399898fe1cb9b52d127ff78f0e11be095563a. Packaging and strict checks pending.127 remains installed.

Sealed package: outputs/IPAStore-builds/iPAStore-1.0.0-rc.29-build128.ipa
SHA256: b4ac75125f72970624a5cfafa2c4e6a8af6439bec7f1849180add7d816c28d42
Strict package checks PASS: CRC, nested signatures, host/extension versions, 128keychain groups and matching native signing-worker selectors. Report: Validation/candidate-checks-1.0.0-rc.29.json. Artwork networking/decoding/cache prefix byte comparison confirms unchanged. Awaiting exact-candidate install-only approval.127 remains installed. User handles phone testing.

## Installed

User explicitly approved128 over127 for installation/version confirmation only. iloader refreshed device availability, imported the exact sealed rc.29build128 IPA and reported Operation completed / Sign & Install App. Independent read-only device inventory confirms iPAStore1.0.0build128. No app launch, UI tests, certificate import/verification, signing, guest launches, downloads or account changes performed. User handles phone testing. Continue128 source for future updates.
