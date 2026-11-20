# Five-page shelves and library navigation · build120 candidate

Base:119, retaining116 navigation/appearance foundation. User handles phone testing; no phone/CLI device tests for120. Install only after exact-candidate approval, then confirm version only.

Changes:
- Shared shelf pagination: three apps per page, up to five pages/15apps when available. Category shelves and Recent use the same helper; More from Library/You Might Also Like request15 instead of9. Category header still opens the entire collection, beyond the preview cap; no repeated/fabricated apps to fill empty pages.
- Library page has exactly Entertainment, Utilities, Games, All Apps in that order instead of generic More Apps. Music/photo/social map to Entertainment; developer/productivity to Utilities; other categories remain in All Apps. All Apps retains every entry from that library. Empty shelves state no apps yet. Today/general grouping remains separate; no new top-level tabs or changed pager.
- Stores attention banner is presentation-only and hidden after leaving the Stores top-level tab, remaining hidden on return. Backend errors, cached catalogs, retry/backoff and refresh scheduling remain. An explicit pull/menu/context refresh allows the next failure notice again. Long-press Update Details keeps recovery available even after the banner is hidden. Merely opening a library/suggestions within Stores doesn't dismiss it.
- Stores menu labels shortened to Refresh/Add. Toolbar Menu label, system body font, default font design/regular weight and native sort Label rows match Apps. Short single-line actions avoid the wrapped oversized rows; native Dynamic Type remains supported.

Validation: release/model suite PASS including four fixed sections, full20-app destination with uncategorized entries retained and distinct15-app/five-page preview. Existing119 cache/refresh/update and earlier signing/atomic replacement model checks PASS; prepared30kquery24ms. Final device Release and preview builds PASS. Strict candidate checks PASS: archive CRC, deep signatures,128keychain groups, native worker selectors and extension versions. No phone interaction or testing performed. Installation awaits exact-candidate approval; user handles phone testing.

Package: `outputs/IPAStore-builds/iPAStore-1.0.0-rc.21-build120.ipa`.
SHA256: `6068eb8701a84cb6ad75e843f8b038c0aabc8ee0a00cd8ddef8d48d23d326e46`.
Report: `Validation/candidate-checks-1.0.0-rc.21.json`.

Installation: user explicitly approved build120. iloader reported Operation completed / Sign & Install App for the exact sealed candidate. Independent read-only device inventory confirms iPAStore1.0.0build120. No phone UI tests, guest launches, downloads or account changes performed; user handles testing.
