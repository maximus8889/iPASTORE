"""Validate the shipped local genre index and quiet, short original success sound."""
from pathlib import Path
import json,wave,struct,sys
root=Path(__file__).resolve().parents[1]
resources=Path(sys.argv[1]) if len(sys.argv)>1 else root/'Resources'
index=json.loads((resources/'AppCategories.json').read_text())['categories']
assert 700<=len(index)<=10000
assert index['com.spotify.client']=='Music'
assert index['com.google.ios.youtube']=='Photo & Video'
assert all(k==k.lower() and 0<len(k)<256 and 0<len(v)<80 for k,v in index.items())
with wave.open(str(resources/'Success.wav'),'rb') as f:
 assert f.getnchannels()==1 and f.getsampwidth()==2 and f.getcomptype()=='NONE'
 duration=f.getnframes()/f.getframerate()
 assert .05<=duration<=.4
 frames=struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))
 assert 0<max(abs(v) for v in frames)<8192
 assert abs(sum(frames)/len(frames))<100
 # The edges/tail must settle quietly so playback does not click or cut off.
 assert abs(frames[0])<32 and abs(frames[-1])<32
 assert max(abs(v) for v in frames[-int(f.getframerate()*.01):])<128
print(f'PASS: {len(index)} local genre mappings; mono PCM success tone {duration:.2f}s, bounded peak/no clipping')
