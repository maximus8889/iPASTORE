# iPAStore

Your apps. One beautiful home.

[Website](https://maximus8889.github.io/iPAStore/) · [Releases and complete source](https://github.com/maximus8889/iPAStore/releases)

## Build 146 candidate

A focused welcome offers Certificate or Free setup. Settings uses matching Sign and Manage controls, a smaller Open Welcome row, and a friendly How iPAStore Works guide. Search stays visible while results scroll. Installed apps remain openable across mode changes, with a switch prompt when needed.

Certificate mode with a matching .p12 and provisioning profile installs separate Home Screen apps. Free mode runs apps inside iPAStore, normally renewing every seven days. On-device pairing supports iOS 27+ and needs a local connection helper; earlier systems require an existing pairing record.

Add as an App creates a native copy using an original IPA. It requires Certificate mode and a valid matching profile. The existing copy stays intact. iOS prevents automatic transfer of private saves into another app; use each app’s supported cloud-save or export/import feature.

The setup profile contains an installer Web Clip only. It does not sign or install the native app. Public native installation still needs a legitimate distribution-signed build. The profile adds no VPN, DNS or management payload.

## Source and verification

The release’s iPAStore-source.tar.gz includes the host and modified signing backend source, exact dependency revisions, retained licenses, build scripts and validation scripts. See README-IPAStore.md and Release1/BUILD146.md. The development IPA requires valid signing before installation. Retain required extensions and keychain groups.

Release builds and fixture checks pass; live phone pairing, real certificate installation and a complete renewal cycle need device qualification. The seven-day renewal schedule depends on iOS and connectivity. No user signing keys, accounts, pairing records or device identifiers are published.

## Credits

Modified LiveContainer and SideStore engines: AGPL-3.0. Zsign-Package: GPL-3.0. Feather is an installation reference. Required notices remain in Credits & Licenses. No SideInstaller code or binaries are bundled. Independent project; not affiliated with Apple or upstream projects.
