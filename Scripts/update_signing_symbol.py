"""Apply the source-equivalent setup symbol to an already compiled pinned service.
Clean source builds already emit the new symbol and require no replacement.
Only an equal-width resource constant changes; no code or signing checks change.
"""
from pathlib import Path
import sys
p=Path(sys.argv[1]);data=p.read_bytes();old=b'checkmark.shield\0';new=b'leaf.circle.fill\0'
assert len(old)==len(new)
count=data.count(old)
if new in data:
 pass
elif count:
 assert count==1, 'Unexpected service resource layout; build the signing backend from source'
 p.write_bytes(data.replace(old,new))
else: raise AssertionError('The signing setup symbol is missing; build the matching service')
