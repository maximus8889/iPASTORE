# Update142: Search header spacing and shorter tab settling

Continue installed141, whose app-page swipes are now user-confirmed twice through the library and once from Search. Preserve its single native transparent navigation bar and native back ownership. User requests Today-equivalent Search top spacing and cautious faster tab swiping after rejecting the previous replacement.

Search root now uses the same hidden navigation-bar policy as Today, horizontal-only20pt content inset and8pt heading top padding. Removes the empty native toolbar row and extra20+4pt top padding. Contained native search field/query/reselect and native pushed-page modifier remain unchanged. This uses the already verified Today-to-library navigation pattern.

Only tab release/cancel settling duration changes: old180+120*remaining milliseconds becomes120+120*remaining, exactly60ms shorter. Existing340ms tap animation, curve, finger tracking, gesture arbitration, commit thresholds, buffering and state cleanup are unchanged. Entire IPATabSwipe.swift and IPANativeNavigation.swift are byte-identical to141. Do not reintroduce140 parallax or gesture proxies.

Preview build and release-model checks pass, including all existing progress/commit/cancel/finite timing cases (bounds updated120–240ms). Device build and sealed package pending. No142 phone installation or physical validation yet;141 remains installed. On-phone targets: Today/Search heading top alignment, standard single app-page Back/Share and physical back from Search, held tab swipe/cancel, rapid reversals and boundaries. No downloads/guest launches/accounts/signing.

Device Release build and strict sealed package checks PASS. Artifact iPAStore-1.0.0-build142.ipa SHA25618d38bf554ef0b3547059cb759b6ba8b0939f5a9ae1d8f7d77a3519f96e34d72. Exact142 install/test approval pending;141 still installed.

## Installed and verified

Exact142 approval received. iloader completed the install using a SHA256-verified byte-identical temporary copy. Independent device inventory confirms1.0.0build142. Fresh142 reports pass native stack/Back attachment/root restoration and tab held reveal/cancel, six rapid reversals/buffered finish, eight boundaries and Reduce Motion. Actual Search-opened AnymeX diagnostics show visible Back/bar and enabled attached native edge/content recognizers.

Visual comparison on the phone confirms Today and Search large headings start at the same height; Search-opened AnymeX has one native Back/Share at normal height. User confirms “Yes, swipe and spacing look right” and tab settling “Feels normal and stable.” Normal launch without test/diagnostic flags completed. No downloads, guest launches, accounts or signing changes. Current working source and installed build142;141 retained as verified prior navigation base. User-designated129 fallback remains intact.
