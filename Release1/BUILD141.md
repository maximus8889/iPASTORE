# Update 141: native navigation and restored tabs

Build 141 is installed and independently version-confirmed. The user approved installation and navigation/layout tests. Continue 141 as current working source; retain 129 as the designated fallback baseline.

Restored the pre-140 production tab coordinator, animator, interaction driver and timing policy exactly. The only construction refactor shares one factory between production and native tests. App pages now use one transparent native navigation bar with system Back and native Share or Get/Open. Removed the floating Back overlay, duplicate trailing-action stack, unused product control and custom edge/content gesture proxies. Child pages share one declarative native navigation policy without recognizer/delegate mutation. Search retains the contained native search field and query behavior, with its large heading lowered in one content header. Approved sound/haptics remain unchanged.

Device Release, preview, release-model regression, strict archive/signature/version/worker and approved audio checks passed. Fresh on-phone reports tagged 141 pass standard navigation attachment/root restoration plus eight tab boundaries, held cancellation, six rapid reversals and Reduce Motion. The live app state also confirms visible native Back/bar and enabled, attached edge/content back recognizers. Temporary native test pages establish framework configuration and transition behavior; they do not prove a physical swipe on a real catalog page.

Observed AnymeX library and app pages: one Back button, native Share at the normal height, transparent toolbar. User confirms both repeat left-edge swipes on the real AnymeX page work. Observed Search with its lowered large heading, then opened AnymeX from Recent: one Back/Share at the same normal height. The separate Search-route physical swipe question remains unanswered; remote drag input is unreliable and is not treated as a gesture failure. Final visual acceptance of the Search heading is user-owned. No downloads, game launches, signing or account changes occurred.

Artifact: `../IPAStore-builds/iPAStore-1.0.0-build141.ipa` (from project parent). SHA256: `6d410250bf2180a9578d5a38edeb1566e46bb3cbf0166b4dd818d8ffc3ba4ea2`.

Raw records: workspace `work/update141/native-navigation.json`, `native-motion.json`, `live-navigation.json`. Build 140 tab visuals are rejected; prior custom swipe attempts remain unverified/failed and have been removed. User confirmed the tested repeat actual-page swipes; do not generalize to every route or cancelled gesture.

Final user confirmation: app opened from Search also swipes back normally. Build141 navigation is the verified base for142; preserve its native page controls and swipe ownership. User rejects excessive empty space above Search and requests Today-equivalent heading layout, plus cautious faster tab settling.
