# Build125-based correction · build127

User reports that More does not open in126 and requests a return to125 behavior, with only latest-update What's New and removal of the divider below Preview. No new animation work is authorized for this correction.

Restored the entire125 storefront file from work/product126/baseline, then applied only the latest-release notes references and Preview divider removal. More/Less and all its preference keys exactly match125 (asserted byte comparison). The four-line What's New preview from125 is restored, replacing126's three-line change. Keep126's release-note scoping helper and removal of the legacy app-description fallback, with regression tests; these implement the requested latest-only notes. Version selector, metadata dividers, pager and all other125 behavior remain unchanged.

126 is still installed.127 is a fresh build identity to avoid overwriting a sealed package. User handles phone testing; no127 phone actions or installation approval yet. Source snapshot before correction: work/product127/baseline. Builds/model checks running.

Device Release and preview builds PASS. Release/model regression suite PASS, including latest-only release notes, product selection, startup, refresh, binary compatibility and signing safeguards. Pager SHA256 unchanged: fe70496b9d7fef66176d2c867f5399898fe1cb9b52d127ff78f0e11be095563a. Package checks pending. No127 phone actions performed.

Sealed package: outputs/IPAStore-builds/iPAStore-1.0.0-rc.28-build127.ipa
SHA256: 316e7f93e5ac70ddf4abe1102b45d9c02bc09656762a7a6cefb519a0e56bd71b
Strict checks PASS: CRC, nested signatures, extension/build versions, 128 keychain groups and matching signing-worker selectors. Report: Validation/candidate-checks-1.0.0-rc.28.json. Awaiting exact-candidate install-only approval;126 remains installed. User handles testing.

## Installed

User explicitly approved127 over126 for installation/version confirmation only. iloader refreshed device availability, imported the exact sealed rc.28build127 IPA, and reported Operation completed / Sign & Install App. Independent read-only device inventory confirms iPAStore1.0.0build127. No app launches, interface tests, guest launches, downloads, account changes or other phone tests performed. User handles testing. Continue127 source for future updates.
