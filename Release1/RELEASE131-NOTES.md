# iPAStore update131

From installed130;129 remains the designated baseline/fallback.

- Open gives brief press/loading feedback. A startup failure automatically retries Compatibility Launch once, retaining the selected data container and launch URL. The launcher preference is remembered for the installed revision and resets after an update. Late running-app failures still offer recovery instead of entering a restart loop.
- Download status stays on one line without trailing dots. The version/edition chooser is hidden while the app has an active installation job, including after a source revision changes.
- User app downloads receive high scheduling priority. Legacy size values are read as scheduling hints, while progress continues to use actual HTTP bytes. Large files, publisher throttling and network conditions still affect speed.
- Categories read more publisher formats, Apple genre IDs and AppTesters’ game marker. No missing/uncertain classification removes an app from All Apps. Publisher metadata can remain incomplete or inaccurate.
- Tapping the selected Search tab scrolls its app list to the top, respecting Reduce Motion. Existing124 native swipe machinery remains unchanged.

Local validation: actual release models/policies/catalog parser; live10120-record AppTesters feed with84 marked game IDs covered; catalog HTTP updates/retries/redirects; native download bytes/progress/pause/resume/cancel/unknown length; device Release and preview compilation; strict package checks all pass. Build131 is installed and independently version-confirmed. Phone Search reselection returns the scrolled list to the top. Fusion reached its menu without a manual compatibility selection after the existing certificate was successfully reverified. Automatic fallback logic passes local tests; its exact Fusion routing was not independently attributed by the layout log. No new accounts or IPA downloads were made.

Category reference: [AppTesters publisher source](https://github.com/apptesters-org/AppTesters_Repo), inspected for its type/genre mapping. Feed snapshot remains in private work files, not bundled with the app.

Package: `iPAStore-1.0.0-build131.ipa`

SHA256: `b68f59890f8bd3c6d1082fd9d474f0718cea0f8f708d8236176c15a5a8e9560c`
