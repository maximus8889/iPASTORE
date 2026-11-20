# Library shelves and scrolling · build 121

Base: build 120, preserving build 119 refresh behavior and the build 116 navigation foundation. Builds 117/118 remain excluded.

Changes:
- Library sections omit empty categories. Libraries containing one displayed app show only All Apps; other libraries retain populated Entertainment, Utilities and Games sections followed by the complete All Apps collection. The five-page/three-row preview and full collection destinations remain.
- Prepare category membership alongside the library's sorted app entries off the main thread, once per immutable source revision. Repeated library view updates reuse the same prepared snapshot. A refreshed catalog receives its own snapshot rather than retaining old categories.
- Replace the nested lazy vertical shelf layout and bounded horizontal lazy pages with stable stacks. Each shelf is still capped at five pages/15 rows; artwork downloads remain bounded and cached. This removes lazy height estimation and page creation work during scrolling. The phone scrolling result is for the user to verify; compilation/model checks cannot establish frame smoothness.
- Clear Artwork Cache now uses the eraser symbol, distinct from Suggestions' sparkles. Cache behavior is unchanged.

Validation: final iPhone Release and simulator preview builds PASS. Release/model suite PASS, including empty/single-app/mixed categories, five-page distinct previews, uncategorized app retention, prepared snapshot consistency and refresh to a single-app revision without stale categories. Existing library refresh/update and signing/replacement regressions PASS. Prepared Search: 30,000 records in30ms. Strict candidate checks PASS: archive CRC, deep signatures,128keychain groups, matching native worker selectors and aligned extension versions.

Package: `outputs/IPAStore-builds/iPAStore-1.0.0-rc.22-build121.ipa`.
SHA256: `36c977b283de4343403700ee713efb64d43d3d3e7e7bd3c6d59706413c4c3236`.
Report: `Validation/candidate-checks-1.0.0-rc.22.json`.

Build120 remains last confirmed installed. No phone testing performed; user handles tests. User explicitly approved this sealed build121 candidate. Installation attempt failed before installing: iloader reported device not found; Refresh Devices returned no devices. Await reconnect/unlock, then retry the same approved IPA without requesting approval again. Only install and confirm version; user handles testing.

Connection follow-up: user replied connected. iloader Refresh Devices still returns no devices. Device Hub sees the phone; read-only CoreDevice inventory confirms paired/connected via localNetwork, not USB. Requested a direct USB data cable/port reconnection. No121 installation or phone tests completed; approval remains valid for this exact candidate.

Second reconnect follow-up: user replied USB connected. iloader refresh still found none; restarted iloader through its UI, same result. macOS USB hardware inventory also contains no iPhone. Requested a different data-capable Lightning cable/direct Mac port. No install occurred. iloader retains a saved login but will need its Sign in action after reconnect; no password was read or changed. Same121 approval remains valid.

Final reconnect: iloader detected the iPhone over USB. Restored its existing saved login, selected the exact sealed rc.22 build121 IPA (hash reconfirmed), and observed Operation completed / Sign & Install App. Independent read-only device inventory confirms iPAStore1.0.0build121. No phone UI testing, guest launches, downloads or account changes performed; user handles tests. Installation is complete.
