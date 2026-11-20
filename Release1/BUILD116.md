# Artwork, detail controls and library refresh · build 116

User owns all phone/app/game testing. Build 115 is the last installed version. Do not launch or test the phone for this update. Prepare candidate 116, then request approval only for installation and version confirmation.

Changes:
- App detail hero scales to viewport width (16:9) rather than a fixed 220-point height, retains pull-to-stretch and fades into the detail background.
- Preview gallery uses actual image proportions, with landscape previews fitted to available width and portrait previews retaining their phone shape. All cards are bounded to the viewport; previews capped at 12. Image size arrives through the existing cached/deduplicated image pipeline; no extra image download or main-thread image decoding introduced.
- Back/Share have explicit 52-point circular visuals and hit areas with 22-point glyphs. Removed the duplicate global status-bar inset from their top placement. No full-width navigation background.
- App/library detail pages use the native elevated dark system background; base tab pages retain the base background. The canvas now respects UIKit's elevation for sheet presentations while retaining the warm light appearance.
- Library refreshes belong to the catalog model. Leaving/redrawing/canceling a SwiftUI page no longer cancels the network operation. Overlapping refreshes share work. Cancellation does not produce a false failed-library state. Real failures retain cached apps and their original reason. One actionable details/retry summary replaces repeated generic errors under every library.

Evidence so far:
- The actual production loader successfully downloaded/decoded all ten curated public test libraries before changes (AltStore, UTM, iSH, Flycast, Ignited, DolphiniOS, Provenance, Feather, StikDebug, community). This is a Mac network check, not proof every user library is reachable on the phone.
- New isolated model regressions pass: caller cancellation, concurrent refresh coalescing, six-hour freshness, offline cached-app retention, cancellation classification, removed-library behavior and recovery.
- Existing release/model checks pass; 30,000-record prepared Search query: 24ms on this Mac.
- Device Release and simulator preview initially compiled successfully. Final control hit-area/library surface changes need final incremental builds.

No phone testing performed. No universal network availability or pixel-exact App Store comparison claimed. No changes to archive extraction, signing eligibility, guest launch, certificate storage or identity checks. Package and install pending.

Final validation: final device Release and simulator preview builds PASS; strict package archive CRC, nested signatures, 128 keychain groups, matching worker selectors and aligned extension versions PASS. All ten public libraries also load with the updated model compiled; their server content can change between probes. Existing signing/extraction guards retained.

Artifact: outputs/IPAStore-builds/iPAStore-1.0.0-rc.17-build116.ipa. SHA256 is recorded in Validation/candidate-checks-1.0.0-rc.17.json. Installation approval pending. No phone/UI/app tests performed.

User approved installation of build 116. iloader has selected the exact rc.17-build116 IPA and is running Sign & Install App for the connected phone. Version confirmation pending. No app testing authorized or performed.

Installation complete: iloader visibly reported Operation completed Sign & Install App. Independent device inventory confirms iPAStore 1.0.0, build 116. No app launch, UI/game testing, signing verification or changes to installed app data performed by the agent. User handles testing. Reinstallation may require Verify Certificate once in Settings → Signing & Refresh before opening container apps.

2026-11-09: user requested rollback from later animation experiments. Original rc.17-build116 IPA checksum matches its sealed report and was reinstalled through iloader without uninstalling the app. Independent device inventory confirms1.0.0build116. Working source restored to116; iPhone Release/preview builds and existing model/catalog/refresh regressions PASS. Future updates start from116. See ACTIVE_BASELINE.md.
