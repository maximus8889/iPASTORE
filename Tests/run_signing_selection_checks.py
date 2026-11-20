"""Exercise the actual signer's bounded runtime-code selector, without credentials."""
from pathlib import Path
import argparse
import struct
import subprocess
import tempfile
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--ipa', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ipastore-sign-selection-') as directory:
    scratch = Path(directory)
    harness = scratch / 'check.cpp'
    harness.write_text('#include "IPASignableMachO.h"\nint main(int n,char**v){for(int i=1;i<n;i++)puts(IPASignableMachO(v[i])?"1":"0");}\n')
    binary = scratch / 'check'
    subprocess.run(['clang++', '-std=c++11', '-Wall', '-Wextra', '-Werror', '-I', str(root/'ZSign'), str(harness), '-o', str(binary)], check=True)

    def thin(kind, wide=True):
        return struct.pack('<8I', 0xfeedfacf if wide else 0xfeedface, 0x100000c if wide else 12, 0, kind, 0, 0, 0, 0)

    def fat(payload, wide=False, big=True, offset=64):
        endian = '>' if big else '<'
        head = struct.pack(endian+'2I', 0xcafebabf if wide else 0xcafebabe, 1)
        arch = struct.pack(endian+('2I2Q2I' if wide else '5I'), 0x100000c, 0, offset, len(payload), 0, *([0] if wide else []))
        return (head+arch).ljust(64, b'\0')+payload

    cases = [(thin(k), k in (2, 6, 8)) for k in (1, 2, 6, 8, 10, 12)]
    cases += [(thin(2, False), False), (b'\xcf\xfa\xed\xfe', False), (b'not code'*5, False)]
    for wide in (False, True):
        for big in (False, True):
            cases.extend([(fat(thin(6), wide, big), True), (fat(thin(1), wide, big), False), (fat(thin(6), wide, big, offset=1<<30), False)])
    paths = []
    for index, (data, _) in enumerate(cases):
        file = scratch / f'fixture-{index}'
        file.write_bytes(data); paths.append(str(file))
    actual = subprocess.check_output([str(binary), *paths], text=True).splitlines()
    assert actual == ['1' if expected else '0' for _, expected in cases], actual
    print(f'Runtime-code selection: PASS ({len(cases)} thin/universal/object/truncation/bounds fixtures)')

    if args.ipa:
        entries, expected = [], []
        with zipfile.ZipFile(args.ipa) as archive:
            for item in archive.infolist():
                if item.is_dir(): continue
                with archive.open(item) as stream: header = stream.read(32)
                if header[:4] != bytes.fromhex('cffaedfe'): continue
                kind = struct.unpack_from('<I', header, 12)[0]
                file = scratch / f'archive-{len(entries)}'
                file.write_bytes(archive.read(item)); entries.append(str(file)); expected.append(kind in (2, 6, 8))
        actual = subprocess.check_output([str(binary), *entries], text=True).splitlines()
        assert actual == ['1' if value else '0' for value in expected]
        assert sum(expected) > 0 and any(not value for value in expected)
        print(f'Reported IPA: PASS ({sum(expected)} runtime files selected; {len(expected)-sum(expected)} build objects untouched)')
