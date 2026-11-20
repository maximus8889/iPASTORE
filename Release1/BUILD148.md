# iPAStore build 148

Tab swipes now move the outgoing and incoming pages the same full distance in either direction. This replaces the overlapping parallax effect while retaining UIKit's interactive progress, cancellation, fast reversal and gesture ownership. App and library pages, including More from this library, retain native push/back navigation.

Suggestions opens as a dismissible discovery sheet. Screenshot previews and publisher web pages have native sheet presentations with their own close controls. Store links, configuration downloads and app handoffs retain their system routes. Game window dismissal fades instead of curling; minimizing no longer shrinks the game. Reduce Motion remains respected by the custom tab animator and native presentations.

Only the Search field stays pinned while scrolling; the Search title scrolls away. The How iPAStore Works subtitle is “A little guidance.” Certificate installation options are disabled and explained until Certificate mode has a valid full certificate/profile setup. Their saved values are preserved.

The obsolete Signing & Refresh hub and unused Installation subpage are removed. Signing recovery offers Go to Settings, closes recovery and resets Settings to its root. Current certificate management, free setup and renewal/reminder controls remain available from their existing settings entries. Legacy service wording is normalized at the recovery display boundary.

Build 147's progress-isolation, bounded artwork decoding, separate icon cache and icon memory fixes are retained. Sign and expiry controls remain Free-only. Community uses https://discord.gg/EQ77PXQQgt.

## Verification

Host and simulator-interface Release builds and release catalog/renewal/compatibility tests pass. Physical-device navigation, motion and artwork results accompany the release, including explicit checks that the pages remain exactly one width apart during held swipes in both directions. Package verification covers archive integrity, deep signatures, extensions, keychain groups and required resources.

Programmatic native transition checks do not substitute for every physical touch trajectory or third-party app workload. Display-link callbacks do not measure rendered FPS. The earlier Time Profiler attempt could not connect to this phone, so no full CPU-trace conclusion is claimed.

## Distribution

The IPA requires legitimate signing; the website configuration profile adds an installer shortcut rather than signing the native app. Free Xcode profiles are app-specific. Free signatures normally require renewal within seven days; background renewal depends on iOS scheduling and connection availability. Private signing files, accounts, pairing records and device identifiers are excluded from release assets.
