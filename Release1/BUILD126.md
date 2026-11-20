> Superseded by the build127 correction: the user reports More does not open in126. Restore125 disclosure behavior and retain only latest-release notes plus removal of the Preview divider. See BUILD127.md.

# App-page follow-up · build 126

Base: installed build 125. Latest user preference: the user handles phone testing. No 126 installation approval yet. Preserve 124 pager, 122 startup/artwork performance, 119 refresh reliability and all existing archive/signing/identity safeguards.

Changes:
- Shared inline More/Less now animates an explicit measured clipping height instead of switching line limits. Long text is measured at full length only when More is requested, while still clipped; the measured expansion then uses the shared spring. Collapsed measurement remains capped at 1,600 characters. The final-line fade, themed inline button, 44-point target, custom fonts, RTL and Reduce Motion are retained.
- What’s New uses only the selected library’s latest release, independent of the download-version picker. Its preview is three lines. A release-heading filter isolates the latest section of cumulative publisher histories while retaining numbered changes and ordinary version mentions. No fallback to another version’s notes or the legacy full app description. Full app description remains in its own section.
- Removed only the divider between Preview and the description beneath it. Metadata bottom divider, What’s New/Preview divider and description’s lower divider remain.

Checks: device Release and preview builds PASS. Release/model suite PASS including new current-release/cumulative-heading/reversed-history/prose/legacy/missing-note fixtures; existing product origin/release selection, catalog refresh, startup, signing and replacement checks remain PASS. Initial compile caught a raw-string escape in the heading expression; corrected before successful final builds and tests.

Backups: work/product126/baseline. Logs: work/product126/{model.log,device-final.log,preview-final.log,package.log}. Native pager hash unchanged: fe70496b9d7fef66176d2c867f5399898fe1cb9b52d127ff78f0e11be095563a. No phone actions performed for 126. No simulator runtime installed; the user will check animation appearance on the phone. Do not claim physically verified animation or universal recognition of unstructured publisher histories. Packaging/strict checks pending.

Sealed candidate: outputs/IPAStore-builds/iPAStore-1.0.0-rc.27-build126.ipa
SHA256: 6c9aaa8e9577a9f26e9a568c942ab2a1e07343b629a72cad489c281b50ebb3dd
Strict package checks PASS: CRC, nested signatures, build/extension versions, signing-worker selectors and keychain groups. Report: Validation/candidate-checks-1.0.0-rc.27.json.
Ready for exact-candidate install-only approval. Build125 remains last confirmed on the phone; no126 phone actions yet. User owns visual/testing checks.

## Installed

User explicitly approved build126 installation over125, install/version-confirmation only. iloader refreshed device availability, imported the exact sealed rc.27build126 IPA and reported Operation completed / Sign & Install App. Independent read-only device inventory confirms iPAStore1.0.0build126. No app launches, interface tests, guest launches, downloads, account changes or other phone tests performed. User handles testing. Continue126 source for future updates.
