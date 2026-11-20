# IPAStore Release 1 — working record

User authorized the complete Release 1 redesign and release analysis on 2026-11-07. Work may be interrupted by usage limits; resume this checklist rather than restarting. Do not label an unvalidated build as a finished release.

## Requested behavior

- Native IPAStore signing setup and one clear Sign Now action. No separate backend storefront or repainted backend settings as the user journey. Keep required licenses in About and internal signing ABI intact.
- Explain pairing and local VPN prerequisites in original, concise setup pages. Automatic renewal selected by default; manual option available. Show real expiration, actual attempt/result state and honest iOS scheduling limitations. Never infer successful signing from opening a screen or saving a preference.
- Product pages link to their originating app library in place of the Installation metadata cell.
- Stores uses the layered-paper symbol; Suggestions entry is an accessible icon. Compact directory rows, dedicated store product pages with descriptions, contained apps and Get. Get adds only when requested. Removal remains available.
- Clean installations start with zero stores. The earlier test subscription on this user's phone must be removed without deleting their apps or other intentionally added stores.
- Empty Stores: layered-paper symbol and “There are currently no stores. Add some in Suggestions.” Empty Apps uses the Apps tab symbol, not the brand glyph.
- Today rotates one suggested store per local calendar day, looping deterministically through the directory. Opens that store's product page. Worth Exploring has genuine category shelves, three app rows per horizontal page and Show All.
- Search has persistent recent searches, no duplicate app variants in idle recommendations, and categorized browsing of every app from user-added stores. Clear/remove recents; useful empty/offline/error states.
- Settings has clear titles, distinct icons and concise explanatory subtitles. Arrangement menu replaces Apps plus, with sorting/custom order only; adjacent Files importer remains.
- Additional quality: accessible typography/VoiceOver/Reduce Motion, consistent spacing and surfaces, metadata caching, stable identities, duplicate handling, deterministic daily rotation, reliable navigation, source attribution, no fake rankings/ratings/categories.

## Baseline

Source: outputs/IPAStore. Last installed development version 0.3.4, build 7. Device engine: LiveContainer.xcodeproj / LiveContainer. Preview: IPAStorePreview.xcodeproj / IPAStorePreview. Main code: Views/IPAStorefront.swift, IPAStoreDirectory.swift, LCAltStoreSourcesView.swift; Models/IPASigningState.swift.

Existing engine keychain ABI MUST remain com.kdt.livecontainer.shared (128 groups); iloader 2.4.1 depends on it. Host identity app.ipastore.IPAStore; public scheme ipastore. SideStore internal identifiers/mangled names are ABI, not presentation. Bundled backend retained for signing until an equivalent implementation is actually integrated. Existing backend settings hooks are a prototype, not the requested native setup.

No accounts, passwords, certificates, pairing records, anisette data or personal device identifiers belong in source/deliverables. Legal notices stay intact. No public publishing or upstream contributions are authorized by this task.

## Work status

- [x] Review current presentation, catalog persistence, signing integration and prior validation.
- [x] Implement release catalog/provenance/category/deduplication model and meaningful checks.
- [x] Redesign directory, store pages, rotating Today, category shelves, search and toolbar/empty states; final direct interaction qualification remains in REVIEW.md.
- [x] Replace backend account-settings journey with original native signing setup and backend bridge; original screen observed on the phone.
- [x] Implement truthful default Automatic policy, expiration tracking, foreground/background attempts and recovery reminders; cycle qualification remains deferred.
- [ ] Review security, compatibility, accessibility, offline behavior, data migration, independent-install limitations and licensing before release.
- [ ] Build, run decoder/business-logic checks, inspect interface and test on physical phone when available.
- [ ] Package a reviewed candidate; distinguish verified behavior from release blockers and update this record.

## Resume instructions

Read this file and the newest entries below. Keep independently useful work moving; ask the user only for credentials, phone trust/unlock, approvals that are actually required, or decisions the existing context cannot resolve. Native signing and reliable renewal are release gates, not cosmetic promises. Do not remove all existing user subscriptions as a migration.

## Decisions and findings

- Fresh installations already load an empty stored-source array; the AltStore subscription visible on this phone was added by the assistant during earlier validation, not bundled defaults.
- Existing app IDs combine bundle identifier and download URL, so release/beta and mirrored sources appear duplicated. Release browsing needs explicit variant grouping and source provenance, without conflating unrelated same-name apps.
- iOS background execution is opportunistic. Automatic preference must schedule best-effort work and provide visible status/recovery, not promise an exact seventh-day wakeup.

### Discovery implementation checkpoint

New files: Views/IPAStoreRegistry.swift (curated descriptions), IPACatalogPresentation.swift (source provenance, grouped editions, categories, daily rotation, bounded persistent search history and cached user-library index). Reworked IPAStoreDirectory.swift and IPAStorefront.swift; Apps toolbar now arrangement-only plus Files; empty Apps uses its tab symbol. Store pages are shared across Today, Suggestions and product-source links. Fresh subscription state remains empty by default. Initial redesign compiles in the simulator target; final device rebuild and business checks are pending. Tests/ReleaseChecks.swift and run_release_checks.py exercise actual production models.

Next: finish these checks; implement a purpose-built native signing controller inside the pinned backend source, avoiding the earlier hidden/repainted settings-controller approach. AuthManager.signIn(presentingViewController:skipResign:skipHowTos:) and PairingFileManager.importPairingFile(from:) are the real reusable APIs. Source is work/SideStore at pinned commit; it uses synchronized Xcode source groups. Private derivative changes are not an upstream contribution; do not publish anything to upstream.

### Native signing implementation checkpoint

Release catalog invariant checks now PASS (Validation/release-catalog-checks.txt). Simulator UI compilation PASS. A private APFS-cloned backend checkout is work/IPAStoreSigningBackend; upstream work/SideStore remains unmodified. New native setup source is outputs/IPAStore/SigningBackend/IPAStoreNativeSigning.swift, copied into its synchronized SideStore/IPAStore source group. It calls actual PairingFileManager, AuthManager, AppBootManager and AppManager APIs, including independent-install notifications. Build is running with derived data work/ReleaseSigningBuild and package cache work/ReleaseSigningPackages; log work/release1/signing-build.log.

Host SideStoreSupport/SideStoreHooks.m now replaces the backend LaunchViewController with the purpose-built native controller and returns only readiness booleans/timestamps to host preferences. It no longer repaints or presents the original backend Settings/My Apps/News controllers. The host hooks MUST ship with the new backend containing @objc IPAStoreSigningController; do not package the old RecoveredSigningService.framework for this revision. A safe mismatch error replaces the backend storefront. Previous hooks snapshot is work/release1/SideStoreHooks-before-native.m.

Pending immediately: compile/fix the new backend; implement host expiration/renewal policy and native signing settings; then build and verify the engine and runtime. Automatic scheduling is not yet implemented. Do not install/package these changes as a release yet.

### Additional user requirements (same Release 1 scope)

New icon: /Users/maximus/Downloads/IPAStore.jpg. Use the exact supplied cream magnifier/compass on black; normalize its visible logo size/padding to native app icons. No substitute logo.

- Actionable recovery for download/install/setup failures. Block Get before network download when signing prerequisites or declared device/iOS requirements are unmet; show original teaching/setup UI with concrete actions. Metadata cannot prove every runtime requirement, so do not claim universal compatibility.
- Real in-page install pipeline with circular measured progress and cancellation; Get starts immediately after prerequisites, no switch to Apps merely to install. Open installed apps directly rather than “View in Apps.” Existing importer/signing/launch engine remains the source of truth.
- Publisher-provided header/screenshot artwork may be used in product heroes with a readable fade; do not invent or scrape unrelated artwork.
- Swipe between top-level tabs without breaking horizontal category shelves, nested navigation or interactive back gestures.
- Search inside each store. Dark canvas should match native App Store black/system surfaces.
- Verify actual download/import/launch behavior on device using an appropriate compatible test app; do not mark signing or guest execution verified from interface tests.

### Current technical checkpoint

Native signing controller successfully compiled once; direct background worker and cancellation improvements added afterward, compilation pending. Host native signing UI, Automatic/Manual policy (default Automatic), actual installed-profile expiry parsing, best-effort BGProcessing scheduling, foreground checks, retry backoff and optional expiry reminders are in source. No fabricated expiry. Readiness must be established through the new setup.

Signing protocol now includes cancelRefresh; SideStoreClient calls IPAStoreSigningController.startRefreshWithProgress:completion: directly, avoiding the old AppIntent 27-second foreground request. IPAResultGate.swift is the shared one-shot completion primitive in both modules. RefreshHandler was rewritten with a serialized lease, reply-before-dispatch gate, startup completion that tolerates early callbacks, cooperative cancellation, and generation-guarded interruption handling. This needs compile and meaningful concurrency checks before packaging.

Immediately before the new user message, device compilation had one corrected NSError/CancellationError coalescing error; backend rebuild was in progress. Logs: work/release1/{device-build,preview-build,signing-build}.log. Do not use the legacy recovered backend with the new hooks.

### In-page installation / QoL checkpoint

Implemented the new requirements in source:

- Exact supplied icon cropped/centered with sips; visible glyph occupies ~67% of the 1024 canvas. AppIcon default/dark/tinted and alternate now use that same new design. Measurement/crop intermediates under work/release1.
- Publisher minOSVersion/maxOSVersion/SHA256, headerURL and string/object/device-specific screenshots are decoded. URLs accept only HTTP(S), metadata reads are cookie-free and bounded to 8 MiB. Source canonicalization preserves queries/non-root path semantics.
- Product Get calls a shared IPAInstallCoordinator, displays a real progress ring/cancel and stays on the page. Installed apps use Open. Publisher imagery fades into the product surface. Store pages have store-only search. Root tab swipes reject horizontal shelves, controls, nested navigation and screen-edge gestures. Gesture behavior still needs runtime verification.
- New IPACompatibility.swift validates numeric OS ranges and bounds-checks Mach-O headers/commands, checks arm64, encryption, platform and minimumOS. The importer inspects the main executable and embedded frameworks/dylibs; checks actual plist identity/device family; verifies published SHA256 when supplied. It rejects prior container metadata and unsafe/malformed packages. Metadata cannot establish all private API/JIT/runtime requirements.
- Production unarchive.m now uses private staging, path/link/type checks, expanded-size/entry limits, disk/cancellation checks, secure symlink flags, duplicate-path rejection and accurate error returns. Real Objective-C extractor fixture tests PASS for valid framework links, traversal, absolute paths, link escapes/following, cancellation and truncation.
- Signing happens before committing the new app. Replacements need confirmation, preserve data/settings, and retain the old app until a signed new package is in place. Files imports copy the user's original, never delete it. Direct URL routes now use this same path and prerequisite checks. Failed signing does not create an Open listing.
- Independent installs now use the native worker/XPC bridge with live pairing/VPN verification before downloading and a verified paid developer team. Host safely extracts/validates the original .app, copies it to its private service incoming folder, and the existing AppManager installs it with actual operation progress. Completion returns real bundle ID/open URL; records appear under On Your iPhone in Apps. Removing a record does not uninstall the physical app. This is implemented and compiled in the backend, but actual independent-install behavior is UNTESTED.
- Cancellation waits for underlying engine completion before releasing the shared signing lease. Callback gates tolerate early/duplicate events. Host worker launch/result race fixes compiled once; further certificate changes are rebuilding now.
- Local certificate date validation added to ZSigner/LCUtils, without OCSP/network requests; preflight rejects missing, unreadable, not-yet-valid or expired container certificates. Revocation/provisioning are separate checks.

Tests: production catalog/renewal/binary/callback-race checks PASS; production archive fixtures PASS. Backend latest build PASS including native independent worker. Device build PASS before the most recent certificate-date checks; recompiling now. Interface preview PASS before last minor changes; rebuilding now. Simulator boot session95898 pending, physical iPhone connected at last inventory. No R1 IPA has yet been packaged or installed.

Next: finish compile, inspect actual runtime/screens/swipe/setup prerequisites, test compatible download/sign/launch with user's setup, fix any issues, harden packaging to require matching native symbols and supply corresponding source/build instructions. Keep release-gate limitations honest. Do not package old RecoveredSigningService with new hooks.

### First physical candidate verification

Candidate IPAStore-1.0.0-rc.1.ipa (1.0.0/build 100) packaged, CRC/deep-strict ad-hoc signatures/keychain ABI/native bridge checks PASS. iloader installed it after the user explicitly approved the local development build at installation time. Device inventory confirmed 1.0.0/build100 and launch succeeded. The signed bundle identity gets an installer team suffix; discover it rather than assuming the unsigned ID. Do not put real team IDs in deliverables.

Native Signing & Refresh displayed actual signature expiry and default Automatic; Set Up Signing successfully opened our own original Signing Setup (not the backend storefront). User explicitly deferred account/pairing/VPN setup: “lets leave that for later.” Do not keep requesting it or claim guest download/sign/launch/renewal verified. Testing those remains deferred at the user's request.

UI checks caught ambiguous tab gesture behavior and nested Suggestions links that did not navigate under Device Hub input. Added singleton recognizer per UITabBarController plus single-transition guard, and replaced library value links with direct destinations. Device Hub enlarged display input appeared unreliable; use Actual Size and take a settled screenshot before acting. User said phone idle when asked, but later returned to Suggestions after deferring setup. Do not fight concurrent phone use.

Further source fixes since rc.1 (not yet installed): cancellation no longer shows a spurious failure sheet; recovery navigates into Signing & Refresh in the same sheet; storage guidance points to General → iPhone Storage; Files retry returns to import; original Inbox file retained. IPAInstallCommit uses tested filesystem RENAME_SWAP for atomic replacement while preserving existing launch paths/shortcuts. Reject updates to active containers. Available Versions menu lets users choose publisher-provided older builds instead of bypassing minimumOS. Known UTM JIT editions and explicit requiresJIT metadata are gated with an honest explanation; guided JIT setup is not yet available and remains a release feature. Unknown runtime requirements cannot be inferred from metadata.

Next: final compile/checks, package rc.2/build101, install under existing authorization if approved, verify repaired links, missing-prerequisite popup, and one-tab swipes at Actual Size. Remove only the assistant's earlier AltStore test subscription if safe; preserve user's Community library. Update final validation record and candidate link; do not label the whole release fully qualified.


### Saved final candidate checkpoint

Source is now frozen for this pass at version1.0.0/build102. Candidate IPAStore-1.0.0-rc.3.ipa and its manifest are in outputs/IPAStore-builds. SHA256: 5846d4143bd1a463aeaacc4589dbd425af2dfa547b5e41b5f9190473a465f11e. Final iPhone/simulator compiles PASS; model/binary/atomic update/callback tests and archive checks PASS. Final package CRC, deep/strict signature, extension metadata, keychain ABI and native worker markers PASS. Validation/package-checks-1.0.0-rc.3.json records those checks. No guest runtime/renewal success is claimed.

The phone was updated to rc.2/build101 and launch verified. rc.3 differs by two small additional bounds/platform checks in the binary validator. Automatic approval review rejected installing rc.3 as a changed payload; a specific action-time confirmation is pending. Do not bypass it. If the user approves, install via the already-open iloader file chooser, verify completion and installed build102; if they decline, leave build101 and provide the saved rc.3 file without claiming it installed. The earlier local-build installation permission was sufficient for rc.2 but the reviewer demanded new permission for rc.3.

Device Hub taps remain ambiguous. Apple documents physical-device interaction, but this session did not reliably forward coordinates. Do not infer functional failure or success from those ambiguous taps. Direct library navigation was made explicit as a defensive fix. A quick on-phone Get → Finish Signing Setup confirmation was requested, but has not yet been answered. User deferred account/pairing/VPN setup, so no more requests to complete that now. Keyboard capture is Off. The old AltStore test subscription has NOT been removed yet; don't claim it has. Preserve user Community subscription.

Release1/REVIEW.md is the durable review and remaining-gate list. Corresponding backend additions match the compiled checkout hashes. README-IPAStore.md and UPSTREAM.md describe the current native controller rather than the superseded repainted backend flow. No public release/publishing was performed.

Final installation remains awaiting the specific rc.3 approval. The file chooser was cancelled safely; build101 stays on the phone and no new installation is running. Reopen Import IPA and select rc.3 after approval. Required CUA completion summary was sent. The on-phone Get-guidance question also remains unanswered; do not infer a result. No further source changes were made after the final build/package.

### User confirmation and rc.3 installation

The user confirmed on the phone that Get shows Finish Signing Setup and guidance instead of downloading. This missing-prerequisite UI check is now PASS (user-confirmed). They explicitly approved final rc.3/build102 installation. The unchanged IPA hash was checked against the saved verified candidate before starting iloader. Installation is in progress; verify completion and installed version before reporting success. Account/pairing/VPN setup remains deferred.

Final rc.3 installation completed and verified: iloader completion, device inventory version1.0.0/build102 and host app process launch all PASS. User-confirmed Get prerequisite guidance PASS. See Validation/device-checks-1.0.0-rc.3.json. The installation approval blocker is resolved. Signing/guest execution/independent-install/renewal-cycle qualification remain deferred or untested; do not claim full release readiness.


### Final refinement candidate — rc.5/build104

Installed with explicit action-time approval through iloader. Device inventory confirms iPAStore 1.0.0/build104; launch PASS. New native signing setup opens and Done returns to the same settings page without restarting the main host process. Corrected actual child Documents-path readiness handoff; physical directory listing confirms consumption after Done. Production tests cover the real path, whitelisted flags/date, repeated reads, old location, invalid and oversized data. Full UI/quality-of-life changes are in Release1/BUILD104.md; checkpoints in REFINEMENT.md.

Final IPA: outputs/IPAStore-builds/iPAStore-1.0.0-rc.5-build104.ipa
SHA256: f6a915bcb8fc4dda3b1813736bb9ba35a80baddbbb73d71c1e5ef314fa78410b
Validation: candidate-checks-1.0.0-rc.5.json, device-checks-1.0.0-rc.5.json, signing-handoff-checks.json, refinement-ui-checks.json. Signing account/pairing/VPN, actual guest installation/launch and renewal-cycle qualification remain deferred by the user. Do not call this a fully qualified public release.


November8 update: rc.7/build106 is installed and native launch confirmed. App-specific crash reports plus archived104 disassembly establish an unguarded optional scene-delegate callback as the reported host crash; fixed in105/106. Added certificate verification and launch/install preflights, mode-specific recovery, reminder guidance, product-page/artwork/sort/search/appearance/swipe refinements. See PRODUCT-PAGES.md and BUILD106.md for exact checkpoint, artifact hash and validation. Real signing/pairing/guest-launch/renewal qualification remains pending; phone coordinate tool failed before input and direct user checks have been requested.
