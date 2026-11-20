# iPAStore 1.0.0 · Build 104

Development candidate rc.5. Supersedes build 103 with a corrected Signing Setup readiness handoff. Signing, pairing and real guest installation remain unqualified until those device tests are completed. This build does not promise universal IPA compatibility or guaranteed background renewal.

Changes include compact library cards and Apps/Web/Developer details, three-line developer truncation, immediate library removal, Add without leaving Suggestions, the complete 87-entry iOS Hub snapshot merged with the existing directory, and publisher artwork with a consistent unavailable-artwork fallback. Marketplace-only editions remain visible with installation guidance.

Today features one library with artwork and a fade, View opens its full app list, Take a closer look opens the library’s details, and Worth Exploring uses only that library’s apps. Category headings use chevrons. Full app lists reveal native search only when requested. Search includes Browse All Apps and horizontally paged recent apps, with a complete searchable/sortable recent-history page.

The readiness handoff now reads the signing process’s actual Documents directory, filters permitted status fields, consumes the file once, and accepts the older location as a fallback. Production checks cover real child-path layout, field filtering, repeat reads, legacy data and malformed/oversized files.

Product pages use filled actions; browsing and Apps use gray/accent actions. Successful installation history enables cloud redownload indicators. Product pages have a compact icon/action while scrolled and bounded More/Less descriptions and release notes. Source feeds without a real banner keep their screenshots in the preview gallery. Apps keeps single-tap product pages, double-tap settings, long-press actions and explicit Open; Sort moves left and import stays right.

Appearance provides light/dark/system display, accent presets and a color picker, system/rounded/serif/monospaced/Monocraft typography, bold text, and included Light/Midnight app icons. Discord help and searchable/sortable download history are in Settings. Visible branding is iPAStore; internal identifiers stay stable for updates and signing.

Signing setup now hosts its isolated signing UI as a page instead of restarting the storefront. Done closes the child scene and hands back readiness flags; secrets remain in the existing keychain. Manual and automatic renewal remain available. Free-account seven-day renewal is explained in Settings; actual provisioning expiry governs validity and iOS controls background timing.

Image requests are bounded, downsampled and cached. Metadata cache reading and catalog sorting run away from navigation work. No measured performance multiplier is claimed.

Directory source: [iOS Hub](https://github.com/CaseyCZ/iOS-Hub), registry snapshot dated October 1, 2026, retrieved November 7, 2026. Original publisher URLs are preserved; offline or unsupported feeds cannot be guaranteed available. Included MIT notice, OFL font license and upstream engine/signing notices are available under Open-Source Licenses.

Validation checkpoint: production catalog/compatibility/renewal/history/atomic replacement checks pass; matching private signing component, simulator and native engine compile. Exact-payload archive, signature, version, entitlement, icon and resource checks pass. Simulator interactions include native search focus, tab swipes, Add staying in Suggestions, scrolled product actions and More/Less release notes. Build 104 passes physical installation, version inventory, launch, Signing Setup/Done navigation, host-process continuity and actual readiness-file consumption on the connected iPhone 14 Pro running iOS 27.2. Account setup and real app installation/renewal-cycle tests remain deferred at the user’s request.

Final candidate: [iPAStore-1.0.0-rc.5-build104.ipa](../../IPAStore-builds/iPAStore-1.0.0-rc.5-build104.ipa). SHA256: `f6a915bcb8fc4dda3b1813736bb9ba35a80baddbbb73d71c1e5ef314fa78410b`. Package, production handoff checks and the physical installation/navigation/handoff checks pass.
