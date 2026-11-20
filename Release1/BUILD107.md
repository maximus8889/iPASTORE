# iPAStore 1.0.0 rc.8 · build107

Candidate SHA256: `9a8fb7b7d23494cee275f4fd70ea9ce92cbd8eb5986361cdb12600fea81b2bb1`.

## Implemented
- Route certificates selected in free-account pairing to the host password/import screen. Recognize p12/pfx, bound and protect the temporary handoff, reject symlinks and consume the owned copy once.
- Explain missing pairing/connection/account steps when tapped. Delay import error presentation until the picker closes. Explain that the existing expiration belongs to the installed signature supplied by the installer.
- Create visible download activity immediately. Show active jobs in Apps with received bytes, pause/resume/cancel and failed-download help/removal. A paused transfer can coexist with other downloads. Installation/signing serialize to preserve existing app data and shared signing state.
- Own downloaded temporary files inside the URLSession delegate. Throttle real byte progress, keep unknown lengths indeterminate, and prevent a paused completion from advancing to installation.
- Distinguish unavailable HTTP links and web-page/non-ZIP responses. Include an extraction-stage diagnostic for ZIP failures. Retain all archive/binary/signature checks.
- Cache certificate dates only while exact certificate/password values match, avoiding repeated PKCS12 parsing during view rendering.
- Retain compact layout, native adaptive blue/immediate tint changes, Suggestions search removal, compact metadata, one library redirect, versions beside Get, fewer section dividers, shortened Sign Now copy and interactive native tab paging with cancel/reverse handling.

## Verified
- Device, backend and simulator builds pass.
- Package checks pass: ZIP CRC, strict nested signatures, all128 requested keychain groups, version-aligned extensions and matching native worker selectors. Development IPA needs account signing; it embeds no real profile.
- Real52MB IPA extraction succeeds on macOS and the iOS simulator.
- Production extractor tests pass for deflate, explicit/late directories, streaming descriptors/ZIP64, framework links, cancellation, truncated archives and unsafe paths/links.
- Actual transfer tests pass for byte equality, file lifetime, pause/resume, a concurrent download while paused, cancellation before start/while paused/in flight, unknown size and HTTP404.
- Native runtime tests pass for actual mid-drag page translation, cancellation, commit, reverse and immediate native tint/adaptive blue.
- Certificate handoff tests pass for one-time consumption, symlink rejection, preserving the original and size bounds.

## Remaining phone qualification
The user’s universal Invalid IPA report has not been reproduced with a named app/library. The new candidate adds specific diagnostics and repairs the transfer lifecycle; do not claim all apps now install. Real certificate import/kernel acceptance, guest installation/launch, pairing/account connection and host renewal need on-device checks. Paused downloads are supported while the app is running; they are not persisted across app termination.

The simulator product page was visually reviewed. Coordinate drag/wheel automation did not move its scroll view, so final hero stretch and compact-header visual behavior still need a direct check. No one-to-one App Store match or universal runtime compatibility is claimed.

User approved install/test107. Installation completed through iloader. Physical inventory confirms107 and the app launched. Today and Settings were visible, retaining the existing dark/green appearance. Certificate verification and a real app installation remain pending.

## User stopped testing — November 8
User said: “u can stop i checked it it works”. Stop further testing/build/install actions. Build107 remains installed. Physical certificate verification was independently observed successful: iOS accepted a test signature. User reports the update works; do not turn that into a claim that every download/runtime, free-account pairing, or renewal was independently verified. No additional library app installation was started. Last phone screen was Stores.
