# iPAStore

Your apps. One beautiful home.

[Website](https://maximus8889.github.io/iPAStore/) · [Releases & complete source](https://github.com/maximus8889/iPAStore/releases) · [Community](https://discord.gg/EQ77PXQQgt)

## Build 148

True side-by-side tab paging in both directions, native app/library back swipes, and contextual discovery, screenshot and browser sheets. Only the Search field stays pinned. Certificate-only options explain their requirements and stay disabled until ready; signing recovery leads straight to Settings.

Includes the build 147 artwork, memory and progress optimizations, Free-only signing controls and refreshed community link. Device checks cover both paging directions, cancellation, rapid reversal, Reduce Motion and all adjacent store tabs. Detailed evidence and limits are in Release1/BUILD148.md and the release attachments.

## Using iPAStore

Welcome offers Certificate or Free setup. Free keeps apps inside iPAStore and normally renews every seven days. Certificate mode with a matching .p12 and provisioning profile supports separate Home Screen apps. On-device pairing supports iOS 27+ and needs a local connection helper; earlier systems require an existing pairing record. Free Xcode profiles authorize specific apps.

How iPAStore Works explains returning from games, signing, app modes and supported save transfer. Add as an App creates a native copy from an original IPA when a compatible certificate/profile is available; the container copy stays intact. iOS prevents automatic transfer into another app’s private save sandbox.

The website’s setup profile adds an installer shortcut only. It does not sign or install the native app. Public native installation still needs a legitimate distribution-signed build. No VPN, DNS or management payload is included.

## Source & build

Download iPAStore-source.tar.gz from the release assets for the host and modified backend source, pinned dependency revisions, retained licenses, build scripts and validation scripts. See README-IPAStore.md, UPSTREAM.md and Release1/BUILD148.md. Keep required extensions and keychain groups when signing the development IPA. No personal signing keys, accounts, profiles, pairing records or device identifiers are included.

## Credits

Modified LiveContainer and SideStore engines: AGPL-3.0. Zsign-Package: GPL-3.0. Feather is an installation reference. Required notices remain in Credits & Licenses. No SideInstaller code or binaries are bundled. Independent project; not affiliated with Apple or upstream projects.
