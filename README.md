# iPAStore

An independent iPhone app built around personal app libraries, a LiveContainer runtime, and a bundled SideStore signing engine.

- [Download & setup](https://maximus8889.github.io/iPASTORE/)
- [Releases and complete corresponding source](https://github.com/maximus8889/iPASTORE/releases)
- [Community](https://discord.gg/uykKvEJFtk)

## Build 144 candidate

Adds a separate certificate-based iPhone installer, provisioning-profile import, destination-aware IPA imports, a fully tappable Library of the Day, reorganized Settings, runtime controls, signing options, and a compact download page.

Standalone certificate installation uses the original app bundle, a complete resource signature and a matching `.p12` + `.mobileprovision`. It does not apply container executable patches. A profile must authorize the app identifier, certificate and device. Extensions and Watch apps require separate provisioning or explicit removal. Container Home Screen icons remain shortcuts into iPAStore.

The certificate installer streams a temporary IPA from a loopback server. A remote manifest service at `api.palera.in` receives the app name, identifier, version and temporary loopback URL; the IPA, profile and certificate stay on the iPhone. iOS makes the final authorization decision. The app records successful installation only after iOS opens the installed app.

Free Setup links to the official SideInstaller tool and its custom IPA handoff. The tool is not bundled or mirrored. Current upstream supports phone-only pairing on iOS 27+; earlier versions require a pairing file made once with a computer. A custom IPA install does not automatically populate every iPAStore account/pairing setting. Free signatures usually require renewal within 7 days. A configuration profile does not replace iOS app signing.

## Source & build

The release's `iPASTORE-source.tar.gz` contains the complete host source, retained licenses, source for the modified signing backend, exact dependency revisions, and build scripts. See `README-IPAStore.md`, `UPSTREAM.md`, and `Release1/BUILD144.md` inside it. The website source is in `docs/` in the source archive and is published at the repository root for GitHub Pages.

Build the host with Xcode:

```sh
xcodebuild -project LiveContainer.xcodeproj -scheme LiveContainer \
  -sdk iphoneos -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath Build/Device CODE_SIGNING_ALLOWED=NO build
```

An unsigned/ad-hoc development IPA requires compatible signing before installation. Keep iPAStore's required extensions and keychain groups when signing. No certificate, private key, pairing record, account or personal device identifier is distributed.

## Licenses & credits

LiveContainer and SideStore: AGPL-3.0. Zsign-Package: GPL-3.0. Additional licenses are retained in the source archive and in Settings → Credits & Licenses. Feather is the reference for the semi-local manifest installation approach. SideInstaller by FrizzleM is an external setup tool, under its own license.

This project is not affiliated with Apple or the upstream projects. Compilation and fixture tests do not establish that every app, certificate, device configuration or renewal cycle works.
