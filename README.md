# iPASTORE

Your apps. One beautiful home.

[Website](https://maximus8889.github.io/iPASTORE/) · [Releases & complete source](https://github.com/maximus8889/iPASTORE/releases)

## Build 145 candidate

First-launch welcome with Certificate or Free setup. Settings has a prominent signing card, organized controls and an Open Welcome button. Apps uses four squares. New signing options include ProMotion, Game Mode, iPad full screen and compression.

Certificate mode installs separate Home Screen apps using a matching .p12 and provisioning profile. Free mode keeps apps inside iPASTORE and renews through an Apple Account. Integrated on-device pairing supports iOS 27+; a local connection helper remains required. Earlier systems need an existing pairing record. Free signing usually expires in seven days; background scheduling depends on iOS.

The website offers a removable setup profile containing only an installer Web Clip. **A profile does not sign or install the native app.** Public native installation awaits a valid distribution-signed build. No VPN, DNS or management payload is added by this profile.

The IPA requires valid signing before installation. Builds and fixture tests pass; native OTA bootstrap, phone pairing, real certificate installs and a full renewal cycle still require device qualification. Keep required extensions and keychain groups when signing.

## Source & credits

Download iPASTORE-source.tar.gz from release assets for complete host and modified backend source, dependency revisions, retained licenses, build scripts and validation scripts. See README-IPAStore.md and Release1/BUILD145.md. Website files are in docs/ and published at the repository root.

Powered by modified LiveContainer and SideStore engines (AGPL-3.0), and Zsign-Package (GPL-3.0). Feather is an installation reference. Required credits remain in Credits & Licenses. No SideInstaller code or binaries are bundled. No personal signing keys, accounts, pairing records or device identifiers are distributed. Independent project; not affiliated with Apple or upstream projects.
