# iPAStore update140

- Common app/library/category/history/appearance/settings pages use native edge and iOS26+ full-content back recognizers, each with a scoped delegate and original-state restoration. UIKit retains its recognizer targets and interactive pop. Full-page swipes yield to controls, text and horizontal carousels. Root/transition/presentation/ownership/leading-direction guards retained. Attachment waits for active transitions to finish to avoid fighting native setup.139 diagnostics showed an enabled/owned edge recognizer but no attempted swipe touch callbacks; no specific user/device cause is asserted.
- Tabs now use navigation-style layered slides: foreground page follows the full travel, background moves30%, with a soft edge and subtle dimming. Stable tab coordinator and linear finger tracking remain. Temporary shadows/dimming/transforms restore on completion/cancellation.
- Tab transition0.30s and proportional80–240ms settling replace the previous180ms minimum tail, making nearly-finished swipes complete sooner. Reduce Motion retains its short crossfade.
- Retains137’s verified single normal-height app-page controls/query restoration and approved soft launch/glass success feedback with independent settings/previews. No sound changes.

Device/preview builds,140 release model/timing checks, actual back policy, sealed CRC/signature/version/worker and sound checks pass. Native temporary-window navigation and tab animation checks plus physical swipe/feel verification pending. No new downloads/accounts/signing.

SHA256: `321574195f5a2b3023ce786d7fc7c67a19cf74efda752a8ff0407746a091aa39`
