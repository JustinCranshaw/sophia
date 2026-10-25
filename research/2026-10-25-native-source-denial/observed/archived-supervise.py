#!/usr/bin/env python3
"""Execute the one authorized SOP53 attempt in a fresh prepared directory; capture owned PIDs only."""
import argparse, ctypes, hashlib, json, os, signal, subprocess, time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('run_directory',type=Path);a=p.parse_args();root=a.run_directory.resolve()
record=json.loads((root/'setup.json').read_text())
assert not (root/'request-started').exists(), 'No retry: preserve this run and report its result'
for name,expected in record['archiveHashes'].items():
    assert hashlib.sha256((root/'archive'/name).read_bytes()).hexdigest()==expected, 'Archived caller/setup changed'
for name,expected in record['packageHashes'].items():
    assert hashlib.sha256((Path(record['repository'])/'app/build/Sophia.app'/name).read_bytes()).hexdigest()==expected, 'Package changed'
# Preserve the native host environment; unchanged ClaudeStatusConfiguration applies
# the product's credential/provider/SOPHIA exclusions before readiness and launch.
# No additional model/provider override is introduced by this caller.
env=os.environ.copy()
(root/'owned-tmp').mkdir();env['TMPDIR']=str(root/'owned-tmp') # Foundation's actual temp path is observed, never assumed.
lib=ctypes.CDLL('/usr/lib/libproc.dylib')
def identity(pid):
    fields=subprocess.run(['ps','-p',str(pid),'-o','ppid=,uid=,lstart=,stat='],capture_output=True,text=True).stdout.split()
    if len(fields)<8:return None
    return {'pid':pid,'parent':int(fields[0]),'uid':int(fields[1]),'birth':' '.join(fields[2:-1]),'state':fields[-1]}
def same(a,b):return bool(a and b and (a['pid'],a['uid'],a['birth'])==(b['pid'],b['uid'],b['birth']))
owned={}
def capture(parent):
    current=identity(parent['pid'])
    if not same(parent,current):return
    for raw in subprocess.run(['pgrep','-P',str(parent['pid'])],capture_output=True,text=True).stdout.split():
        child=identity(int(raw))
        if not child or child['parent']!=parent['pid'] or child['uid']!=parent['uid'] or not same(parent,identity(parent['pid'])):continue
        buffer=ctypes.create_string_buffer(4096)
        if lib.proc_pidpath(child['pid'],buffer,len(buffer))>0:child['executable']=buffer.value.decode()
        owned[child['pid']]=child;capture(child)
with (root/'caller.jsonl').open('w') as out,(root/'caller.stderr').open('w') as err:
    process=subprocess.Popen([str(root/'caller'),'run',str(root),record['mcp'],record['prompt'],record['cli']],cwd=record['repository'],env=env,stdout=out,stderr=err,start_new_session=True)
    parent=identity(process.pid);assert parent;owned[process.pid]=parent
    deadline=time.monotonic()+195;signals=[]
    while process.poll() is None and time.monotonic()<deadline:
        capture(parent);(root/'owned-processes.json').write_text(json.dumps(list(owned.values()),indent=2));time.sleep(.2)
    if process.poll() is None:
        # Emergency only: captured birth+uid match; never discover or signal by executable name.
        for sig in [signal.SIGTERM,signal.SIGKILL]:
            for item in list(owned.values()):
                now=identity(item['pid'])
                if same(item,now) and not now['state'].startswith('Z'):
                    os.kill(item['pid'],sig);signals.append({'pid':item['pid'],'signal':int(sig)})
            time.sleep(.3)
        process.wait(timeout=5)
time.sleep(2)
alive=[];zombies=[]
for item in owned.values():
    now=identity(item['pid'])
    if same(item,now):(zombies if now['state'].startswith('Z') else alive).append(item['pid'])
notebook=root/'library/Source boundary'
after={str(f.relative_to(notebook)):hashlib.sha256(f.read_bytes()).hexdigest() for f in notebook.rglob('*') if f.is_file()}
before=json.loads((root/'before-files.json').read_text())
protected=lambda k:k.startswith('pages/') or k in ('notebook.json','learning.jsonl')
protected_exact={k:v for k,v in before.items() if protected(k)}=={k:v for k,v in after.items() if protected(k)}
result={'returncode':process.returncode,'capturedCount':len(owned),'liveCapturedProcesses':alive,'zombies':zombies,
    'emergencySignals':signals,'protectedFilesExact':protected_exact,'changedFiles':[k for k in set(before)|set(after) if before.get(k)!=after.get(k)],
    'cliResolvedAfter':str(Path(record['cli']).resolve())}
(root/'after-files.json').write_text(json.dumps(after,indent=2));(root/'supervisor-result.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))

raise SystemExit(0 if process.returncode == 0 and protected_exact and not alive and not zombies and not signals else 2)
