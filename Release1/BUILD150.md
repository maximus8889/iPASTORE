# iPAStore build 150

- Download circles show the actual download fraction instead of a 40% allocation of overall installation work. Installation uses an activity indicator with its current phase, avoiding a backwards progress jump. Completion changes to the installed app state only after installation succeeds.
- Free signing, expiry text and Renewal & Reminders require pairing, a saved account and a successfully verified local connection. Renewal scheduling also checks readiness and Free mode. Existing preferences are retained; unavailable controls are disabled.
- Saved account signing material is restored and verified automatically after an update changes the installed provisioning profile. Launch and download requests await that recovery. Verification is retained, concurrent recovery is coalesced, and explicit certificate removal prevents silent reimport.
- Certificate and provisioning-profile management includes removal of the saved copies. Original files and installed app data are retained.
- Add as an App offers Download & Install for an exact matching catalog identifier when the original IPA cache is unavailable. Choosing a local original remains a fallback. iOS sandboxing still prevents automatic private save-data migration.
- Certificate and Free symbols match across settings, welcome, outer management and inner free setup. Welcome completion actions share the same dimensions/style. Settings group headers use normal case and the system section-header font.
- Includes build 149's clear pinned Search field, cancellable/shared artwork, bounded library revisions and catalog/custom-order optimizations. Existing native app/library swipes, contextual sheets and direct Settings recovery remain.

## Automatic renewal

Renewal checks when iPAStore becomes active and requests iOS background processing. For a seven-day signature, its target is about 1¾ days before expiry. Completed setup, account access and a working local connection are required. iOS controls background scheduling; force-quitting, connectivity and account errors can prevent renewal. Check expiry yourself as well. A complete multi-day renewal cycle has not been verified in this update.

## Validation and source

Release compilation and package integrity/signature checks are performed. Interaction testing is left to the user as requested; no claim of exhaustive device, download or renewal testing is made. The final release is published before installation on the connected iPhone.

The setup symbol is a resource-only equal-width UTF-8 update in the pinned service, applied before signatures are regenerated. The matching source overlay and repeatable packaging script are included; a clean service source build already emits that symbol. No control flow, authentication or signing verification is patched out.

The IPA needs legitimate provisioning/signing. The website configuration profile adds an installer shortcut rather than signing the native app. Source, retained licenses and build scripts are provided; private keys, profiles, accounts, pairing files and device IDs are excluded.
