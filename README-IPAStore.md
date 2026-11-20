Build 150: see Release1/BUILD150.md for download progress, readiness gates, update recovery, signing-file removal and native-copy downloads.

Build 149: see Release1/BUILD149.md for artwork cancellation/sharing, bounded revision caches, catalog/custom-order benchmarks and Search layout verification.

Build 148: see Release1/BUILD148.md for true tab paging, contextual presentations, pinned Search field and direct Settings recovery.

Build 147: see Release1/BUILD147.md for measured navigation and artwork performance, Free-only signing controls, the updated community link, and verification limits.

> **Historical build 144.** Adds full standalone certificate signing and iOS installation, profile import, destination-aware downloads/imports, a tappable featured library, reorganized settings, free-setup handoffs, and a GitHub download page. See [BUILD144](Release1/BUILD144.md). Old build records below are historical.

> **Historical update133, from installed132.** Adds scoped automatic compatibility selection, black return fades/local return signaling and a quicker-presenting Apple Account setup page. Local checks/builds/strict package pass; build133 installed/version-confirmed and bounded user-assisted Account/return/Fusion checks pass. Compatibility launch still has an iOS-managed process transition. See [current results](Release1/BUILD133.md) and [release notes](Release1/RELEASE133-NOTES.md).

> **Historical baseline: build129.** The user designated update129 as the base for future iPAStore work. Preserve its accumulated fixes and continue from129. Older116rollback and117/118experiment records are historical. See [baseline record](Release1/ACTIVE_BASELINE.md).

# IPAStore 1.0.0 — release candidate

IPAStore is a private derivative with an original SwiftUI storefront, the LiveContainer runtime and a bundled SideStore signing engine. Required licenses and corresponding source remain in Settings → About and ThirdParty. The current candidate is for device testing; compilation and packaging do not establish guest compatibility or reliable renewal.

## Interface and installation

Today rotates a suggested library daily. Suggestions offers compact listings and shared library pages. Adding a library is explicit; fresh installations have none. Stores supports removal, categories and store-specific search. Search includes recent searches and categorized apps from subscribed libraries, grouping mirrored and preview editions without discarding their origins.

Get stays on the product page, with actual download/extraction/signing progress and cancellation. Missing signing prerequisites and publisher-declared OS requirements are shown before downloading. The original package is inspected for device family, arm64, platform, encryption, minimum OS and embedded framework compatibility. Explicit JIT declarations and known UTM JIT editions are gated; guided JIT installation is a remaining release feature. UTM SE is excluded from that gate. See the publisher’s official guide at https://docs.getutm.app/installation/ios/. Published SHA256 checksums are verified when supplied. This cannot prove every private API, JIT, entitlement or runtime requirement. Imported apps are committed only after signing succeeds; replacements require confirmation and keep their data/settings. Files imports do not delete the original file. Installed apps offer Open.

Certificate mode installs separate iPhone apps using a matching .p12 certificate and .mobileprovision profile. The profile must authorize the app, device and capabilities; iOS makes the final authorization decision. Container mode keeps apps inside iPASTORE. Container Home Screen icons remain launch shortcuts. Removing a standalone listing does not uninstall the system app.

## Signing and refresh

First launch shows Certificate and Free choices. Settings → Open Welcome reopens the choices. Free Signing provides guided on-device pairing on iOS 27+, a local connection helper and an Apple Account. Earlier systems require an existing pairing record. Authentication remains inside the existing signing engine. Never enter account credentials in chat. Sign Now uses the direct signing worker rather than an AppIntent foreground-continuation deadline. The installed provisioning profile supplies the real expiration date.

Automatic renewal is the default. IPAStore schedules best-effort background work and checks on foreground entry, with backoff and visible last-attempt/result state. iOS decides when background work runs; automatic does not guarantee renewal after force quit, without required networking, or at an exact time. Optional expiry reminders are available. Manual mode remains available.

## Build, source and validation

- LiveContainer.xcodeproj / LiveContainer: iPhone engine, minimum iOS 17.5, Swift 5 mode.
- IPAStorePreview.xcodeproj / IPAStorePreview: simulator interface only; cannot sign or execute IPAs.
- `python3 Tests/run_catalog_checks.py`: actual production feed decoder.
- `python3 Tests/run_release_checks.py`: catalog variants, categories, source identity, local daily rotation, DST, search persistence, OS/binary requirements, profile-expiry policy and callback races.
- `python3 Tests/run_archive_checks.py`: production Objective-C archive extraction with safe and hostile fixtures.
- `Scripts/build_signing_backend.py --work <new-directory>` reconstructs the private backend from the pinned corresponding-source archive plus SigningBackend/IPAStoreNativeSigning.swift and the shared IPAResultGate.swift. ThirdParty/signing-source-manifest.json records exact source revisions and modification hashes.
- `Scripts/package_development.py` packages local builds and requires matching native bridge selectors. It retains the engine's 128 installer-compatible keychain groups, necessary extensions and internal ABI. Do not substitute an old signing-service framework.

Preserve OpenSSL symbolic links and framework signature verification. The distributable IPA has only ad-hoc transport signatures: use a real installer/account to provision and re-sign it, retaining all extensions and the main profile. Candidate and verification results are in the sibling IPAStore-builds directory and Validation. Release1/PROGRESS.md records remaining release gates. No passwords, signing identities, pairing records or personal device IDs belong in these artifacts.

This is an independent project; it does not imply Apple endorsement or App Store review. Backend protocols, signing limits and iOS runtime restrictions still apply. Required credits are kept in About even though normal navigation uses IPAStore branding.
