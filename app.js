"use strict";

(async () => {
  const nativeInstall = document.getElementById("native-install");
  if (!nativeInstall) return;

  try {
    const response = await fetch("distribution.json", {
      cache: "no-store",
      credentials: "omit",
      signal: AbortSignal.timeout(8000)
    });
    if (!response.ok) return;

    const distribution = await response.json();
    if (distribution.ready !== true || typeof distribution.manifest !== "string") return;

    const manifest = new URL(distribution.manifest);
    if (manifest.protocol !== "https:") return;

    nativeInstall.href = "itms-services://?action=download-manifest&url=" + encodeURIComponent(manifest.href);
    nativeInstall.hidden = false;
    document.getElementById("availability").textContent = "Install directly or download the IPA.";
  } catch {
    // The IPA link remains available if the signed installer is unavailable.
  }
})();
