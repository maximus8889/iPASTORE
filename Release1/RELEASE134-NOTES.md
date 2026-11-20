# iPAStore update134

- Corrects a hosted app’s explicit exit-on-background flag, preserves its original value and forces the existing signer to reseal the change. Original IPAs and game data are retained. Flappy Bird’s installed copy has this flag enabled; the user-assisted one-second Home/return retest passes.
- Retains the hosted controller across view reconstruction/window detach, pauses startup timeouts while interrupted, and prevents interrupted exits from becoming compatibility-launch preferences. Reuses live guests; bounded same-container recovery and an explicit Continue offer handle interrupted sessions. iOS can still terminate suspended processes and unsaved game memory cannot be recreated.
- Adds a local factual genre index for 766 of AppTesters’ 789 unique app identities. Current feed coverage is Entertainment239 / Utilities439 / Games84 / All Apps789. Publisher categories take precedence and unknown apps remain available in All Apps. No runtime bulk lookup or new IPA download.
- Replaces matched zoom page transitions with standard interactive NavigationStack slides, retaining build124’s tab pager.
- Adds a subtle launch haptic and quiet original success tone after actual completed installation, verified certificate or successful renewal. Foreground/system sound behavior is preserved; Appearance includes controls and a preview.
- Frees reconstructible artwork RAM on background/memory pressure while retaining disk originals; pauses catalog polling while a hosted game is active.

Model/lifecycle/category, actual native window/return callback, plist/re-sign intent, ImageIO disk reuse and feedback-asset checks pass. Device Release and preview compile. Sealed archive CRC, signatures, aligned versions and signing worker checks pass. Build134 installed and independently version-confirmed. User confirms Flappy stays open after the one-second Home/return test; game menu observed and the same host/guest process IDs remain. Readback confirms the hosted flag is false, original value preserved and re-sign marker cleared. Longer/lock/memory-pressure behavior and sound/haptic perception/new download/free-renewal feedback were not independently tested. No universal/background-memory guarantee.

SHA256: `1de2ab79445f3eae5e7121b863d83f8e0ec047bd80521e38e817363b5dfc4090`
