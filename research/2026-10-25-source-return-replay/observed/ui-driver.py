import json,subprocess,time,os
from pathlib import Path
APP=Path('/tmp/sophia-source-replay')
def ui(run,action,**args):
    cmd=['python3',str(APP/'app/scripts/ux.py'),str(run),action]
    for k,v in args.items():
        cmd.append('--'+k.replace('_','-'))
        if v is not True: cmd.extend(map(str,v if isinstance(v,list) else [v]))
    r=subprocess.run(cmd,cwd=APP,capture_output=True,text=True)
    if r.returncode:raise RuntimeError(r.stderr or r.stdout)
    output=json.loads(r.stdout)
    if 'result' in output: output=json.loads(Path(output['result']).read_text())
    if output.get('error') or output.get('performed') is False: raise RuntimeError(str({'action': action, 'error': output.get('error'), 'performed': output.get('performed'), 'screenshot': output.get('screenshot')}))
    return output
def latest(run):
    return json.loads(sorted((Path(run)/'results').glob('*.json'))[-1].read_text())
def element(result,label=None,role=None):
    rows=[x for x in result['tree'] if (label is None or x.get('label')==label) and (role is None or x.get('role')==role)]
    if not rows:raise RuntimeError(f'UI element missing {label} {role}')
    return rows[0]['id']
def press(run,label):
    rows=[x for x in latest(run)['tree'] if x.get('label')==label]
    if not rows: raise RuntimeError('UI element missing '+label)
    target=next((x for x in rows if x.get('class')=='AccessibilityNode'),rows[0])
    return ui(run,'press',id=target['id'])
def send(run,text):
    r=latest(run); field=element(r,role='AXTextField');ui(run,'set',id=field,text=text);return press(run,'Up')
def quit_app(run):
    with open(str(run)+'-quit.log','w') as f:
        subprocess.Popen(['python3',str(APP/'app/scripts/ux.py'),str(run),'key','--code','12','--modifiers','command','--text','q'],cwd=APP,stdout=f,stderr=f,start_new_session=True)
    pid=int((Path(run)/'pid').read_text())
    for _ in range(50):
        try:os.kill(pid,0)
        except ProcessLookupError:return
        time.sleep(.1)
    raise RuntimeError('App did not exit via Quit')

def chat_area(result):
    return [x for x in result['tree'] if x.get('role')=='AXScrollArea'][1]['id']
def chat_fraction(result):
    return float([x for x in result['tree'] if x.get('role')=='AXScrollBar'][1]['value'])
def has_jump(result):
    return any(x.get('role')=='AXButton' and x.get('label')=='New activity' for x in result['tree'])
