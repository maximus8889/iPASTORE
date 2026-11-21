"""Compile the actual release catalog and presentation models with real feed-decoder checks."""
from pathlib import Path
import subprocess
import shutil
root = Path(__file__).resolve().parents[1]
scratch = root / '.build' / 'ReleaseChecks'
scratch.mkdir(parents=True, exist_ok=True)
shutil.copy2(root/'Resources/AppCategories.json', scratch/'AppCategories.json')
source = (root / 'LiveContainerSwiftUI/Views/LCAltStoreSourcesView.swift').read_text().split('struct LCSourcesView: View')[0].replace('import UIKit\n', '')
source += '\nextension String { var loc: String { self } }\n'
(scratch/'Catalog.swift').write_text(source)
discovery = (root/'LiveContainerSwiftUI/Views/IPAStoreDirectory.swift').read_text().split('extension AltStoreSourcesViewModel')[0]
(scratch/'Discovery.swift').write_text(discovery)
(scratch/'Runner.swift').write_text('import Foundation\n@main struct Runner { @MainActor static func main() async throws { try await ReleaseChecks.run() } }\n')
command = ['swiftc', str(root/'LiveContainerSwiftUI/Models/IPAGuestLifecycle.swift'), str(root/'LiveContainerSwiftUI/Models/IPAAppCategoryIndex.swift'), str(root/'LiveContainerSwiftUI/Models/IPACompatibilityLaunchPolicy.swift'), str(root/'LiveContainerSwiftUI/Models/IPADownloadTransfer.swift'), str(scratch/'Catalog.swift'), str(scratch/'Discovery.swift'), str(root/'LiveContainerSwiftUI/Models/IPAAppPresentationPolicy.swift'), str(root/'LiveContainerSwiftUI/Models/IPAProductMetadata.swift'), str(root/'LiveContainerSwiftUI/Models/IPASigningSetupHandoff.swift'), str(root/'LiveContainerSwiftUI/Models/IPAActivityHistory.swift'), str(root/'LiveContainerSwiftUI/Views/IPAStoreRegistry.swift'), str(root/'LiveContainerSwiftUI/Views/IPACatalogPresentation.swift'), str(root/'SideStoreSupport/IPAResultGate.swift'), str(root/'LiveContainerSwiftUI/Models/IPARenewalPolicy.swift'), str(root/'LiveContainerSwiftUI/Models/IPACompatibility.swift'), str(root/'LiveContainerSwiftUI/Models/IPAInstallCommit.swift'), str(root/'Tests/ReleaseChecks.swift'), str(scratch/'Runner.swift'), '-parse-as-library', '-swift-version', '5', '-module-cache-path', str(scratch/'ModuleCache'), '-o', str(scratch/'checks')]
subprocess.run(command, check=True)
result = subprocess.run([str(scratch/'checks')], capture_output=True, text=True)
if result.returncode:
    print(result.stdout)
    print(result.stderr)
    result.check_returncode()
(root/'Validation/release-catalog-checks.txt').write_text(result.stdout)
print(result.stdout)
