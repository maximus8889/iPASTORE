# iPAStore 1.0.0 · build 130

- Faster artwork reuse: display cached images immediately, reuse compressed originals for different sizes, and avoid repeated PNG encoding. Newly downloaded artwork keeps the existing fade.
- More reliable artwork lookup: share connections, recover from temporary failures, keep usable cached metadata offline, and stop queued lookups when their pages are no longer needed.
- Smoother app-page navigation: save recent history in the background and combine rapid updates while preserving cleared and downloaded records.
- More efficient startup: reuse fresh library catalogs and retain automatic stale checks and manual refresh.
- Cache reliability: clearing artwork cancels pending work so older downloads cannot refill it afterward.

Built from baseline129. Existing interface, app-opening transition, signing setup, appearance, version selection and installation safeguards are preserved.
