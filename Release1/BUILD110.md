# Library availability and icons · build110

Audited87 directory feeds and10 built-in addresses.84 directory responses were valid JSON and all84 passed the production decoder;3 endpoints were unavailable/HTML/timed out. All10 curated addresses responded with catalogs. AppTesters10.3MB and FastSign23.1MB exceeded the old8MB source limit.

Changes:32MB bounded delegate-owned catalog downloads replace slow per-byte async iteration; retain size limits for both declared and unknown lengths, HTTP validation and source decoding. Resolve live relative URLs against final response URL. Existing IPA transfers keep their original unlimited network configuration and existing archive bounds.

Directory merging now preserves artwork and marketplace flags for matching built-in entries. Recovered7 missing icons from existing publisher/directory sources (Yattee, Kodi, NineAnimator, BringYour, Wayfarer, Burrito, Winston), with source records in Resources/LibraryArtworkRepairSources.json. Two inaccessible publisher icons use named library fallback rather than a blank image. SVG assets compile through the native asset catalog.

Per-library request state prevents premature Unavailable screens. Failed discovery feeds retry after60seconds without refetching successful feeds until the normal6-hour refresh. Existing cached catalogs remain available on failures. Library icons can fall back to the first app that actually has an icon.

Validation: release regressions PASS (including known-library artwork merge), transfer regressions PASS (including limits with known/unknown content lengths), production feed decoder audit84/84 PASS, iPhone build PASS, candidate package checks PASS. iOS runtime qualification PASS: all7 recovered icons load, alongside existing archive/pager/tint checks. Third-party offline endpoints cannot be repaired locally or treated as healthy.

Candidate110 packaged; not installed yet.109 remains installed and its gesture/return was confirmed by user.

Candidate SHA256:90b55707e4648a9a3952301fe3ebe9a4be01bdf6f20171b9724f0027e206cc2d. User approved110; physical installation in progress.

Installation complete; physical device inventory confirms110. No independent phone browsing test claimed.
