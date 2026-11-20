# Upstream provenance

LiveContainer: https://github.com/LiveContainer/LiveContainer
Commit: 9108ae624ea001f7d7696d48407f890b48fa2653
License: AGPL-3.0, retained in LICENSE.

IPAStore modifies the storefront, catalog presentation, installation safeguards, renewal scheduling and display branding. Internal executable and runtime class names remain intact; the host has a distinct bundle identifier and public launch scheme. SideStore integration code is present upstream, but its bundled executable is a separate packaging step; this source tree does not include that executable.

## Signing service (development 0.2)

The bundled service is compiled locally from the pinned LiveContainer/SideStore LiveContainerSupport branch. Its source is unmodified. Exact repository and package revisions are in ThirdParty/signing-source-manifest.json, and corresponding checked-out source (including submodules and Swift package checkouts) is in ThirdParty/signing-service-corresponding-source.tar.gz. Packaging changes its display name, converts the executable using the pinned MIT-licensed dylibify tool, and places it inside the host using the upstream engine's existing layout.

The derivative has its own app.ipastore.IPAStore host/extension identifiers and ipastore launch scheme. Launcher links use ipastore; the installer-compatible keychain group ABI is retained as documented below. The upstream self-update feed hook is disabled so an upstream build is not advertised as an IPAStore update.

### Installer compatibility correction

The app and extension identities remain app.ipastore.IPAStore, and the account service uses the host identity for its own keychain service names. The engine’s com.kdt.livecontainer.shared keychain access-group ABI is retained because iloader 2.4.1 explicitly supplies these groups when signing a bundled container/service app. These access groups can be shared with other LiveContainer-based apps signed by the same team; a distinct bundle identifier does not imply separate keychain isolation. The native Signing flow now checks all 128 required groups before reading account state or launching the signing service. A fully separate namespace requires a compatible signer change as well as an engine change.

## Development 0.3 presentation changes

The compiled service source archive remains unmodified. The host-side SideStoreSupport integration now hides the backend browsing tab bar when entering account setup, selects its existing Settings controller, supplies a return action, and brands localized presentation strings. Original controller indices and signing APIs are retained. Credits, license notices, third-party app identities, internal URLs and service identifiers are preserved. The signing intent now throws explicit errors for missing listeners/extensions instead of silently returning success.

The host integration also replaces only the signing setup's AppIcon image requests with packaged IPAStore artwork, mirrors the host appearance on service windows, and uses system blue. Its native pairing, network and account setup steps remain intact; their completion is not implied by installation.

The signing account table now uses neutral native surfaces and readable labels. Non-signing promotion, appearance and upstream-update sections are hidden; the native IPAStore About screen retains legal credits. Table row indices, authentication and certificate actions are preserved. These host-side presentation hooks target the pinned compiled service; changing that service requires renewed runtime validation.


## Release 1 private derivative

The current native signing journey supersedes the 0.3 table/tab repainting hooks above. The original backend checkout remains unchanged; a private build adds SigningBackend/IPAStoreNativeSigning.swift and the same SideStoreSupport/IPAResultGate.swift used by the host. The new controller calls the existing pairing/authentication managers and provides direct cancellable renewal and installation workers. It does not replace Apple authentication or signing protocols. The host embeds that original setup controller instead of constructing backend browsing tabs.

ThirdParty/signing-source-manifest.json records the pinned source archive and addition hashes. Scripts/build_signing_backend.py reconstructs and builds that derivative. Scripts/package_development.py requires the native setup/renewal/install selectors, preserves internal identifiers, normalizes extension metadata and creates only ad-hoc transport signatures. The original source archive plus the two added files constitute the corresponding backend source for this candidate. Host changes are provided in this exported source tree, with upstream licenses intact.

Install extraction is now bounds/path/link checked and cancellable. Container updates sign in private staging and commit via atomic directory exchange, retaining existing app paths and data settings. Live signing and guest runtime behavior still require device validation with completed account/pairing setup. No public upstream contribution or publication has been made.

## Build 144 standalone certificate installation

ZSign/bundle.cpp and bundle.h originate from khcrysalis/Zsign-Package at Feather's pinned revision c4ba9da (GPL-3.0; license in ThirdParty/Zsign-Package-LICENSE.txt). iPAStore adapts the class to its existing ZSign engine, rejects unused dylib-removal requests, propagates signing failures and corrects embedded-profile retention. The existing ZSign Mach-O signer now propagates CMS construction failures. The new certificate bridge validates profile membership and uses complete resource seals. The manifest/loopback approach is informed by Feather's semi-local installer; its Vapor/TLS implementation is not copied.

The corresponding signing-service source archive was reconstructed from the exact local checkout matching the bundled backend additions. Its refreshed checksum is in ThirdParty/signing-source-manifest.json. The archive includes those original IPAStore additions; the reconstruction helper safely re-applies the identical files. Swift package revisions remain pinned in ThirdParty/Signing-Package.resolved and the manifest.

Free Setup links to SideInstaller by FrizzleM (https://github.com/FrizzleM/SideInstaller). No SideInstaller source or release binary is incorporated or redistributed. Its native custom-IPA URL handoff is used as a public integration surface.
