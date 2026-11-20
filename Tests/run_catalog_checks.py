"""Run the real feed decoder on macOS, without an iPhone or simulator."""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[1]
scratch = root / '.build' / 'CatalogChecks'
scratch.mkdir(parents=True, exist_ok=True)
source = (root / 'LiveContainerSwiftUI/Views/LCAltStoreSourcesView.swift').read_text()
# Compile the same model/decoder as the iPhone app; omit unrelated view declarations.
source = source.split('struct LCSourcesView: View')[0].replace('import UIKit\n', '')
source += '\nextension String { var loc: String { self } }\n'
(scratch / 'CatalogUnderTest.swift').write_text(source)
(scratch / 'main.swift').write_text('import Foundation\ntry CatalogChecks.run()\nprint("Catalog checks passed")\n')
subprocess.run([
    'swiftc', str(scratch / 'CatalogUnderTest.swift'),
    str(root / 'Preview/CatalogChecks.swift'), str(scratch / 'main.swift'),
    '-module-cache-path', str(scratch / 'ModuleCache'), '-o', str(scratch / 'catalog-checks')
], check=True)
report = root / 'Validation/catalog-checks.txt'
subprocess.run([str(scratch / 'catalog-checks')], check=True,
               env={**os.environ, 'IPASTORE_CHECK_REPORT': str(report)})
print(report.read_text())
