import sys,json,time,subprocess,shlex,hashlib,os,shutil
from pathlib import Path
sys.path.insert(0,'/tmp/sophia-sop32-prep');import ui
root=Path('/tmp/sophia-sop32-current-ui');run=str(root);app=int((root/'pid').read_text());owned={};bridges=set();decisions=[];seen=set();stopped=None
allowed={'https://cuny.manifoldapp.org/read/black-reconstruction-in-america-toward-a-history-of-the-part-which-black-folk-played-in-the-attempt-to-reconstruct-democracy-in-america-1860-1880/section/aa903055-6ea8-4a69-a130-5195b8a41832','https://www.ericfoner.com/articles/011321NYer.html'}
def identity(pid):
 a=subprocess.run(['ps','-p',str(pid),'-o','ppid=,uid=,lstart=,stat='],capture_output=True,text=True).stdout.split()
 return {'pid':pid,'parent':int(a[0]),'uid':int(a[1]),'birth':' '.join(a[2:-1]),'state':a[-1]} if len(a)>=8 else None
def capture(pid):
 for s in subprocess.run(['pgrep','-P',str(pid)],capture_output=True,text=True).stdout.split():
  n=int(s);i=identity(n)
  if not i or i['parent']!=pid:continue
  owned[n]=i;cmd=subprocess.run(['ps','-p',s,'-o','command='],capture_output=True,text=True).stdout.strip();args=cmd.split()
  if '--source-permissions' in args:bridges.add(Path(args[args.index('--source-permissions')+1]))
  capture(n)
def archive_bridges():
 for b in bridges:
  for f in b.glob('*.json'):
   dst=root/'continuation-bridge-evidence'/b.name;dst.mkdir(parents=True,exist_ok=True)
   try:shutil.copyfile(f,dst/(str(time.time_ns())+'-'+f.name))
   except FileNotFoundError:pass
question='For this controlled verification, please continue the comparison using the two source responses already returned. I stopped the last turn at an approval budget, not because those sources failed. If needed, request focused extraction from the same two URLs. Distinguish quotations from your interpretation and give only locators actually available. Leave every page unchanged.'
ui.ui(run,'inspect');started=time.time();(root/'continuation-send-proof.json').write_text(json.dumps({'question':question,'sendStartedEpoch':started,'deadlineEpoch':started+360,'appPID':app},indent=2));ui.send(run,question)
while True:
 capture(app);archive_bridges();x=ui.ui(run,'inspect');buttons=[a.get('label') for a in x['tree'] if a.get('role')=='AXButton']
 if 'Allow once' in buttons:
  requests=[]
  for b in bridges:
   try:q=json.loads((b/'request.json').read_text())
   except (FileNotFoundError,json.JSONDecodeError):continue
   if q.get('nonce') not in seen:requests.append(q)
  if len(requests)!=1:stopped='Ambiguous pending request; no approval';break
  q=requests[0];seen.add(q['nonce']);ok=q.get('url') in allowed and len(decisions)<4
  label='Allow once' if ok else "Don't open";ui.press(run,label);decisions.append({'request':q,'action':label,'at':time.time(),'screenshot':x.get('screenshot')});(root/'continuation-decisions.json').write_text(json.dumps(decisions,indent=2));print('decision',label,q.get('url'),flush=True)
  if not ok:stopped='Unexpected URL or approval cap';break
 # Actual persisted WebSearch records; stop third search only when no source content has arrived.
 transcript=root/'library/Freedom and citizenship/transcript.jsonl';rows=[json.loads(l) for l in transcript.read_text().splitlines()];new=rows[53:];searches=[a for a in new if a.get('tool')=='WebSearch'];fetches=[a for a in new if a.get('tool')=='WebFetch' and not a.get('is_error',False)]
 if searches:stopped='Unexpected search outside continuation scope';break
 if 'Stop' not in buttons:
  stopped='Turn idle';break
 if time.time()>=started+360:stopped='Six-minute cap';break
 time.sleep(.2)
print(stopped,flush=True)
if stopped!='Turn idle':
 x=ui.ui(run,'inspect')
 if any(a.get('label')=='Stop' for a in x['tree']):ui.press(run,'Stop')
archive_bridges();final=ui.ui(run,'inspect');(root/'continuation-native-outcome.json').write_text(json.dumps({'reason':stopped,'elapsed':time.time()-started,'decisions':decisions,'screenshot':final.get('screenshot'),'owned':list(owned.values()),'bridges':list(map(str,bridges))},indent=2));ui.quit_app(run);time.sleep(1)
alive=[]
for old in owned.values():
 now=identity(old['pid'])
 if now and (now['uid'],now['birth'])==(old['uid'],old['birth']):alive.append(now)
n=root/'library/Freedom and citizenship';after={str(f.relative_to(n)):hashlib.sha256(f.read_bytes()).hexdigest() for f in n.rglob('*') if f.is_file()};before=json.loads((root/'continuation-before-files.json').read_text());protect=lambda k:k.startswith('pages/') or k=='notebook.json';proof={'appGone':identity(app) is None,'liveCaptured':alive,'protectedExact':{k:v for k,v in before.items() if protect(k)}=={k:v for k,v in after.items() if protect(k)},'changedFiles':[k for k in set(before)|set(after) if before.get(k)!=after.get(k)],'bridgesRemoved':all(not b.exists() for b in bridges)};(root/'continuation-after-files.json').write_text(json.dumps(after,indent=2));(root/'continuation-cleanup-proof.json').write_text(json.dumps(proof,indent=2));print(json.dumps(proof),flush=True)
