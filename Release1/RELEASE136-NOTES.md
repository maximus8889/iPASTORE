# iPAStore update136

- Search and its current product page now coordinate native navigation-bar visibility. Search hides the whole native row while the product page owns its floating controls, then restores the root bar on return. No manual control offsets. Older page disappearance cannot clear a newer page owner.
- Removes135’s native-back-hidden override; default native swipe-back behavior is retained without replacing gesture delegates. Phone checks pending.
- Includes135’s soft-lift/crisp-settle launch haptic, native success haptic and original0.34s quiet glass-like success tone. Stale launch taps cancel; background/disabled feedback is suppressed; nearby successes coalesce. Centralized success hooks avoid duplicate install vibration. Appearance offers independent sound/haptic controls and separate previews.

Device Release and preview builds plus sealed CRC/signature/version/worker checks pass. Packaged sound edges/tail/peak are valid;135 release and feedback scheduling checks remain applicable to unchanged code. Phone verification pending. No new downloads/account changes.

SHA256: `9da8b5b63858bc3748f75d21fab66a3b8d76a13be3d60dabb08d07aeaa7912d2`
