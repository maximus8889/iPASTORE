# Performance, motion and full-screen launch · build112

Candidate: iPAStore1.0.0rc.13build112. Development IPA requires account provisioning. SHA256:9c2a8a136175211813096d9cd6025e9aaa29c0fcaef1818ef9f693a35b20d6f5.

## Performance
Library grouping, cache restoration, collection filtering and recommendations are prepared off the main actor or cached. Source identifiers and entry categories are calculated once. The five native tab roots retain their state instead of being replaced on selection. Large results grow in100-row batches, with all results remaining scrollable. Download progress is throttled before main-thread dispatch and updates the active job, avoiding global redraws for every byte. Installed-state lookups use a cached identifier set. Collapsed long text measures a bounded prefix.

Feed date formatters are reused within a decode, without sharing mutable formatters between concurrent decodes. On the same84saved feeds/28,740listings, decoding measured9,228ms before and3,756ms after on this Mac. This is a decoding benchmark, not a phone frame-rate measurement. Additional fallback categories add grouping work; grouping now runs off-main. Prepared30,000-record query regression32ms.

## Launch and interaction
The return shortcut is a two-finger double-tap in the lower half. It keeps simultaneous recognition, does not cancel ordinary game touches and respects VoiceOver. The existing per-scene authenticated return callback is retained.

Eligible non-JIT/non-classic iOS18+ apps open in a full-screen isolated LiveProcess scene while the storefront remains alive. Geometry follows window bounds and supported orientations. Removed guest root-view entry scaling; compatibility launches animate only an overlay snapshot. An error page offers the original compatibility path; Direct Launch can be disabled in Settings. JIT, classic and explicitly requested multitask launches retain existing paths. Direct launching is not a claim that arbitrary IPAs work or that Apple signing requirements are removed.

## Presentation and storage
Product pages use floating controls without a full-width navigation background. Metadata columns use equal centered widths. Library apps have category shelves. Today retains View and removes the duplicate closer-look action. Settings and Signing & Refresh use shorter descriptions and clearer sections. Artwork-cache management removes only replaceable artwork; installed apps, data and signing material are preserved. Owned abandoned download/staging temporary folders older than24hours are cleaned up. Required frameworks, engine resources and licenses are retained.

Motion includes native icon-to-product/library zoom on supported systems, press feedback, short artwork/get-state/expandable-text/search transitions and existing interactive native tab slides. Reduce Motion uses simpler transitions.

## Validation and remaining qualification
Device Release build PASS; simulator preview build PASS. Release catalog, binary/atomic replacement/renewal/callback checks PASS. Package CRC, strict nested signatures,128keychain groups, worker selectors and extension-version alignment PASS. No real provisioning profile included.

The Mac currently has no installed simulator runtime. The connected iPhone is visible but unpaired; both Device Hub and iloader require pairing before testing. Exact build112 installation-and-test approval has been requested. The candidate has not yet been installed. Full-screen guest lifecycle, physical landscape/portrait rendering, two-finger return, live visual review and actual device responsiveness still need qualification. Existing111 remains installed. No promise of zero lag or universal app compatibility.

## Physical installation checkpoint
User approved build112 and testing Flappy Bird/SuperMario64. iloader completed installation; device inventory independently confirms version1.0.0build112. Xcode pairing restored. Stored certificate re-verified successfully (green check). Today artwork, categorized library shelf, Settings/Signing & Refresh and product floating controls observed. Native tab slide observed mid-transition and settled normally.

Flappy Bird opened in the full-screen hosted scene. Process inventory confirms host PID8335 remains unchanged while LiveProcess PID8358 runs separately. Ordinary single-finger double-tap continued gameplay without return overlay. Two-finger return confirmation requested from user because Mac phone view cannot generate multitouch. Landscape/SuperMario64 remains pending.
