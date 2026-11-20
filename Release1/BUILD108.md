# Focused Invalid IPA fix · build108

Build107 physical failures observed in Apps: iSH and DolphiniOS. iSH Help & Recovery reports: Creating app files: Cannot extract through symlink app staging/Payload. Certificate test signature was already accepted on the phone. This isolates the observed failure to the extraction writer’s path handling, not the certificate/password flow.

Replaced libarchive disk-writer path traversal with descriptor-anchored mkdirat/openat/pwrite/symlinkat operations. Every archive-controlled parent opens with O_DIRECTORY|O_NOFOLLOW; files use exclusive creation and O_NOFOLLOW. Retains two-pass entry/path/link/size validation, byte bounds, cancellation, private staging and later signing/atomic commit checks. Directory records can precede or follow files. No archive code executes during extraction.

Archive regression suite PASS. Device and preview Xcode builds PASS. Package/CRC/strict signature/keychain groups/extension versions PASS. iOS extraction runtime report is Validation/fix108-runtime.json. New IPA: iPAStore-1.0.0-rc.9-build108.ipa. SHA256:d5e2648514f670025052bd63b2e9c76935b5c728531699a5939f0dc6833d015a.

User approved108. Installing through iloader. Need confirm the exact physical iSH failure is gone; no universal launch compatibility claim.

## Physical result
Build108 installed successfully through iloader and launched. User directly retested and confirmed: “i tested it myself and i can confirm it works”. Stop further test actions. The iSH retry initiated by the agent reached certificate re-verification after the installer changed the host profile; the user then used the phone and confirmed success. Do not claim the agent independently observed a completed guest installation or launch. No pairing/account renewal claim.
