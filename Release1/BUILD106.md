# iPAStore rc.7 — build 106

Candidate: iPAStore-1.0.0-rc.7-build106.ipa

SHA256: `2d8471bf9354e6f4261e069b4aeb51b415b85b6719bfe40138016c48007772ba`

Includes all crash, certificate, recovery, product-page, artwork, sort/search and appearance work documented in BUILD105.md.

Follow-up refinements:
- Independent installation has its own setup explanation and an explicit switch to Apps in iPAStore. Importing a container certificate no longer sends this mode through the same generic setup loop.
- Apps uses gray Open pills with the chosen accent, matching the existing list buttons.
- Known certificate-probe timeout/component failures show their own explanation.
- Renewal cannot report success if the completed results omit iPAStore itself; safe service errors are retained in the renewal status.
- Broken public catalog icons can fall back to an exact matching Apple listing, with bounded lookup concurrency. Stremio retains its bundled publisher fallback.
- Screenshot hero selection avoids obvious login/sign-in filenames when another supplied screenshot is available. Dates use compact relative formatting.

Validation: native engine, matching service and simulator compile passed; production-model checks passed; package CRC, strict/deep signatures, 128 requested shared keychain groups, extension alignment and matching service selector/source checks passed. Compiled service contains the new host-renewal safeguard.

Device state: the user approved build106, iloader completed its installation, exact device inventory confirms bundleVersion106, and native launch succeeded. Real certificate acceptance, pairing/account connection, guest installation/launch and complete renewal remain unqualified. The Mac device-control coordinate interface currently fails before taps are delivered, so direct user feedback was requested for certificate verification, VPN handoff and idle stability.

This development IPA requires real signing/provisioning by the installer. Certificate acceptance and app compatibility depend on actual device/provisioning/runtime requirements; automatic renewal remains subject to iOS background scheduling.
