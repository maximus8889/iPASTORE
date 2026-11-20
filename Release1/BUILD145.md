# Build 145 — Welcome and simpler setup

- First-launch welcome with Certificate and Free choices; reopen using Open Welcome at the bottom of Settings.
- Certificate setup imports the matching .p12 and .mobileprovision. Free setup opens an original iPASTORE screen with pairing, local connection and account steps.
- Native wireless pairing uses the already-bundled Minimuxer API on iOS 27+. Pairing PIN notification, timeout, cancellation, callback generation guards, temporary record cleanup and background expiration handling are included. No SideInstaller code or binaries are copied. A local connection helper remains required; this has not yet been tested end to end on the phone.
- Settings uses matching cards, an Installation Method header, a prominent Sign iPASTORE action and grouped signing, runtime, appearance, storage and update tools.
- Apps tab uses the four-square icon. Today’s featured library remains fully tappable.
- New real signing options: ProMotion, Game Mode, iPad full screen and compressed installation packages. Files access, extension/Watch removal and classic appearance remain available. Compatibility depends on each app and iOS.
- Website reduced to a short introduction and a setup-profile download. No external signer chooser or setup tutorial. The removable profile contains only a Web Clip to the installer page, with clear consent text. It does not install/sign the native app. The native OTA action stays disabled until a valid distribution-signed build and HTTPS manifest are configured in distribution.json.

## Validation

Host iPhone and simulator-interface Release builds, modified native backend Release build, catalog/renewal/callback checks, hostile archive checks, profile/resource/CMS signature checks and loopback installer checks pass. Compressed and stored packages are compared file by file and checked for correct ZIP compression methods and CRCs. Synthetic signer fixtures do not establish Apple authorization. No simulator runtime is installed, so simulator interaction is unavailable. Final package verification is recorded separately.

## Open qualification

Public native installation through the profile requires a legitimate distributable signing identity/profile. Free setup, system pairing prompts, standalone certificate installation and a full seven-day renewal cycle still require end-to-end device qualification. Do not describe these as verified from compilation.
