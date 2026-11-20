# Build 147 — Navigation and performance

- Sign and installed-app expiry appear in the Settings hero only in Free mode. Certificate mode has its own heading and a Manage control.
- Community now uses https://discord.gg/EQ77PXQQgt. Discord’s public API returned 200 with the expected invite code.
- Tab transitions retain the existing UIKit interactive driver, buffered finish/cancel events, selection ownership and root-only gesture guards. Push/pop-style parallax and faster easing replace the full-width carousel movement. Slow deliberate horizontal gestures work without a velocity floor; vertical scrolling, horizontal shelves and native detail-page Back remain separately handled.
- Custom button zoom, reveal zoom and spring bounce were replaced with opacity fades and eased slides, including the container dock. Functional native indicators and interactive window geometry remain.
- Frequent download/signing progress updates now publish through the active job or a small file-progress model. They do not invalidate the store-wide coordinator. The phone check delivered 400 progress publications with zero store-wide publications.
- Artwork decode concurrency is bounded at two. Disk writes/pruning run on a separate actor after decoded-image delivery, and generation tokens prevent stale writes after a clear. Icons and large images now have separate cache budgets without increasing the total 40 MiB decoded cache allowance; large images do not replace small preview entries.
- Fixed the retained CGImage reference when loading installed-app icon files, and guarded corrupt cached icon data before constructing UIImage.

## Verification on the connected iPhone

- Native motion checks: held progress, held cancellation, both directions, rapid reversal/buffered completion, all eight synthetic boundaries, all eight real store-content boundaries, Reduce Motion and final view/selection cleanup pass.
- Held completion: build 146 about 251 ms; build 147 about 170 ms (roughly 32% shorter in this run). Actual store-page release settlements were about 161–199 ms. These are local measurements, not guaranteed timings on every device.
- Real artwork pipeline: 128 locally cached-image requests completed in about 411 ms. All 16 tested icon entries survived large-artwork loads; sixteen warm requests completed in about 0.14 ms. Cache-clear and rejection of stale disk writes pass.
- Standard native navigation bar, edge/content Back recognizer attachment and stack restoration pass. Physical touch trajectories still require hands-on interaction; programmatic transition checks do not replace those.
- Display-link callback sampling recorded a 95th-percentile interval around 16.7 ms and a worst gap around 96 ms across cold setup/content transitions. Callback cadence is not a measurement of rendered FPS. Do not claim zero hitches from this sample.
- Host and simulator-interface Release builds, catalog/renewal/compatibility/callback tests, slow-pan/invalid-input policy tests and final package CRC/deep signatures/keychain/extension checks pass.
- Full Time Profiler recording could not start: Instruments listed the phone offline although CoreDevice installation and native checks worked. No CPU-trace conclusion is claimed.

Raw native checks and the prior-build baseline accompany the release. No account credentials, certificates, provisioning profiles, pairing records or personal device IDs are published.

## Existing distribution/runtime limits

The configuration profile is an installer Web Clip; public native bootstrap still needs legitimate distribution signing. Free signatures normally need renewal within seven days and background renewal remains subject to iOS and connectivity. Each native app needs compatible provisioning; free Xcode profiles are app-specific. Native save transfer, third-party app compatibility, a full renewal cycle and every possible multitasking arrangement are not established by these checks.
