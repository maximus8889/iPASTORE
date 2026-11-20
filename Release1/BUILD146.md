# Build 146 — Consistent controls and installed-app behavior

- Uniform 46-point Sign and Manage controls in both modes; no layout shift on mode changes. Removed the duplicate Signing & Certificates row. Smaller matching How iPAStore Works and Open Welcome rows.
- Welcome has no close X. Certificate and Free use matching seal/leaf icons in Welcome and Settings. Setup pages keep their back navigation without duplicate page titles. Free setup shows Finish Later until pairing, connection and account flags are complete, then Start Using iPAStore.
- Account sign-in retains the existing authentication implementation with iPAStore’s canvas and a Signing Account title. No Welcome to SideStore heading. Verification, account connection and pairing completion provide foreground-only success feedback respecting sound/haptic preferences. Automatic certificate verification on Done is silent.
- Search field stays outside the scrolling results. Horizontal tab swipes require a clearer horizontal gesture, reducing diagonal-scroll interference. Smoothness still needs real-device profiling; no simulator runtime is installed.
- Product Get/Open recognizes installs in either mode. Container launch offers Switch & Open when Certificate is selected without an imported certificate. Existing native installations open using their native launch URL.
- Add as an App is first in the Add to Home Screen menu and requires Certificate mode plus a matching provisioning profile. It installs from a bounded cached original IPA or asks for the original. It never signs a container-patched executable as a native app. Existing container data stays intact. iOS does not permit automatic private save/settings migration to the native copy; the confirmation and guide explain app-supported transfer options.
- Original cache is best effort, runs off the main actor, holds at most 1 GiB and skips individual packages at least 512 MiB. Cache loss/failure does not fail installation. Re-import file copies also run off the main actor.
- User-facing branding, GitHub repository name and website use iPAStore. Website uses a softer purple accent. Technical bundle identifiers stay stable for data compatibility.

## Verification

Device host, simulator interface and modified backend Release builds pass. Mode-selection matrix, real original-cache replacement/eviction/oversize/source-preservation tests and existing catalog, binary, renewal and callback-race checks pass. Existing archive, standalone-signer and loopback-server checks passed for unchanged paths in build 145. Package verification is recorded separately.

## Remaining qualification

A public configuration profile alone cannot install/sign a native IPA. Public native bootstrap remains gated on a valid distribution signing identity and HTTPS OTA manifest. Live pairing, actual standalone certificate installation, app compatibility, save transfer through each app and a full seven-day renewal cycle remain device-specific checks. Do not describe these as fully qualified from compilation.
