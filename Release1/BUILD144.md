# Build 144 — iPhone installation and Settings

## Changes

- Certificate installs now use the original bundle and full ZSign resource signing with a matching provisioning profile, without container executable patches. Certificate/profile private-key membership, team, time bounds, app identifier and distribution type are checked. iOS makes the final device authorization decision.
- Streaming ZIP output and loopback HTTP transfer bound memory use. A random path exposes only the signed IPA. The remote HTTPS manifest receives app metadata and the loopback URL, never certificate files or IPA bytes.
- Installation is recorded after iOS successfully opens the independent launch URL. A system installation prompt alone is not treated as success.
- Files, links and product downloads honor the selected installation destination. Existing container copies do not suppress the independent Get action. Converting a container app does not migrate its private data into the standalone app.
- Today’s Library of the Day is a full-card navigation link; the View button is removed.
- Settings groups signing, free setup, installation, appearance, runtime, storage, history, updates and credits. Added profile import and real signing options for Files access, extension/Watch removal and classic appearance. Exposed existing JIT, multitasking, multiple containers, link behavior and diagnostics.
- Free Setup opens the official SideInstaller website and custom IPA install link. No SideInstaller binaries or noncommercial code are bundled. Custom IPA setup still requires importing pairing and connecting the embedded signing account. Phone-only pairing depends on upstream-supported iOS versions.
- GitHub Pages download site and stable GitHub release download links. Updates remain subject to iOS approval and signing.
- Signer hardening: propagate CMS and nested Mach-O signing failures; retain embedded profiles by fixing upstream's reversed flag; support full wildcard profiles; free parsed CMS buffers.

## Verification

- iPhone Release build: PASS.
- Simulator interface build: PASS. No simulator runtime is installed, so interactive simulator testing is unavailable.
- Existing catalog, binary compatibility, atomic replacement, renewal policy and callback-race tests: PASS.
- Production archive extraction hostile/valid fixture tests: PASS.
- New profile and bundle signature fixtures: PASS. CMS cryptographic verification, SHA256 code-page/Info/resource slot verification, resource-tamper detection, streamed IPA CRC, profile retention and cancelled ZIP cleanup pass. Synthetic test certificates cannot establish Apple/device authorization.
- Loopback installer: PASS for 12 MiB transfer, HEAD length, URL/Unicode encoding, stable launch scheme and refusing private-file routes.
- Package CRC/deep strict signatures/extension and keychain ABI checks: recorded separately in Validation/build144-package.json.

## Qualification still needed

Real standalone installation with a user's valid certificate/profile/device combination; large real IPA transfer through iOS installation services; automatic renewal cycle; free setup end-to-end; per-app runtime compatibility. Do not call these verified from fixture tests or compilation.

No user certificates, passwords, pairing records, accounts or device identifiers are included in the release or source archive.
