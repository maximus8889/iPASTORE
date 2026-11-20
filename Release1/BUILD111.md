# Search performance and identity review · build111

User reports Search lag and SuperMario64 App Identity Didn’t Match. Library name not supplied. Directory snapshots show SuperMario64 in CyPwn/FastSign with declared cypwn.SuperMario64.1.0.0 and a CyPwn download URL. Mac metadata-only retrieval returnedHTTP403, so actual bundle identity was not independently obtained. No guessed mapping or silent whitelist added.

Search state moved out of root into its own tab; keystrokes no longer update all five native hosting roots. Normalized name/developer/subtitle/category/library search documents prepared once with catalog indexing, search runs off the main actor with150ms debounce, cancellation and generation checking. Ranking uses prefix partition of already sorted rows instead of repeated sorting/normalization. Regression verifies equivalent ordinary query matches. Prepared30,000-record benchmark33ms on Mac; physical typing not independently timed.

Mismatched IDs now require an explicit cancel-by-default Review Downloaded App alert, showing actual package name/ID and listing ID. Archive, original-package, device/runtime, binary, signing and atomic replacement checks retained. User can install a compatible downloaded app as a reviewed import; a mismatch is never silently accepted. After successful commit only, store a per-source/listing alias so Open targets the actual installed identifier. Cancellation resumes the review continuation without installing. This does not make encrypted/incompatible/JIT-only apps universally installable.

Device build PASS, release/regression checks PASS, strict package/CRC/128keychain groups/worker selectors/extension alignment PASS. Artifact:iPAStore-1.0.0-rc.12-build111.ipa. SHA256:be0bcc1658b728040410394ba31b9bef88c9472e5f9f448a34e6f1f115de4f6e.

User approved111; installing through iloader. Mario guest install/launch and review flow still require direct on-device confirmation. Prior108 extraction fix and109 return control retained.
