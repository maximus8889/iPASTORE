# Release 1 review — current candidate

The installed candidate is **iPAStore 1.0.0 rc.7 / build106**. iloader completed the user-approved installation; native device inventory confirms build106 and launch succeeds. The saved IPA is `outputs/IPAStore-builds/iPAStore-1.0.0-rc.7-build106.ipa`, SHA256 `2d8471bf9354e6f4261e069b4aeb51b415b85b6719bfe40138016c48007772ba`. This remains a development candidate.

## Included

Build106 retains the directory, rotating library feature, library categories, global browsing, recent/download history, inline installation progress, version selection, custom icons/accent/fonts, Discord help and original iPAStore presentation. This update adds revised product pages, publisher/screenshot artwork fallbacks, exact-identity Apple listing metadata, repaired Stremio artwork, consistent Sort/Search controls, saved library arrangement, Files-left/Sort-right Apps controls, live Appearance styling and revised tab-slide handling.

The reported signing-page crash is traced to an optional scene callback invoked unconditionally. Two app-specific reports and disassembly of archived104 establish the exact failing call. It is guarded in105/106. Missing credentials no longer count as successful signing. Certificate readiness requires a fresh test signature accepted by iOS; launches and staged installs also check the executable before proceeding. Setup separates Apple Account, own certificate, host renewal and independent-install requirements. Recovery explains signature/runtime/setup failures, reminders report permission/scheduling problems, and a renewal result must include iPAStore itself. See BUILD106.md and PRODUCT-PAGES.md.

## Verified

- Native engine, matching signing component and simulator compile.
- Production catalog/origin/variant/category, OS and Mach-O validation, atomic replacement, history, renewal policy, callback-race and real-directory handoff checks.
- Additional exact metadata identity, insecure URL rejection, response bounds, launch-error classification and independent-mode recovery checks.
- Exact package CRC, deep/strict ad-hoc signatures, aligned extension versions,128 requested keychain groups, required resources/selectors and matching private-derivative hashes. Compiled component includes the host-renewal-result safeguard.
- Simulator105 interaction: Stremio icons, Today -> library category -> product, screenshot-backed header, metadata strip, notes/gallery/info/related sections, Get -> Help & Recovery before download.
- Physical105: existing Flappy Bird/StikNES entries and purple/Monocraft settings preserved; icons render. Physical106: installer completion, exact installed version and native launch.

The physical coordinate-input tool subsequently fails before delivering taps (`noWindowsAvailable`); native host controls and simulator accessibility actions still work. User checks have been requested for certificate verification and VPN open/return/idle stability. Their results are pending. No new host crash report appeared in the narrow post105 filename check, but this does not qualify all triggering paths.

## Remaining release qualification

- Obtain the on-phone certificate-verification and VPN/idle results, then complete pairing/account setup privately and test recovery. The latest request supersedes the earlier setup deferral.
- Download, sign, install and actually launch a compatible publisher app. Test cancellation/replacement with retained data; qualify independent installation with a suitable paid account and provisioning.
- Verify actual host renewal and background behavior across expiry. iOS controls background scheduling; a successful build is not a successful renewal test.
- Qualify physical swipe animation, tap/double-tap settings, alternate icons, large text, VoiceOver and Reduce Motion. Some earlier UI behavior was checked in104; newly changed paths require current-candidate qualification.
- JIT-dependent editions remain gated unless a compatible launch setup exists. Binary/catalog validation cannot guarantee every app’s runtime compatibility.

No credentials, certificates, pairing records or personal device identifiers are included in these delivered validation records. Licenses and signing ABI identifiers remain intact. No public release or upstream contribution was posted.
