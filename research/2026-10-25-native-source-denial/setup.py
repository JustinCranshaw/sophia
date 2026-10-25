#!/usr/bin/env python3
"""Prepare one fresh SOP53 run. Never invokes the model; supervise.py is a separate explicit step."""
import argparse, hashlib, json, os, shutil, subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--repository', type=Path, required=True)
p.add_argument('--run-directory', type=Path, required=True)
p.add_argument('--expected-main', required=True)
p.add_argument('--require-commit', action='append', required=True)
p.add_argument('--claude', type=Path, default=Path.home()/'.local/bin/claude')
a = p.parse_args(); repo = a.repository.resolve(); root = a.run_directory.absolute()
def command(*args):
    return subprocess.check_output(list(map(str,args)), cwd=repo, text=True).strip()
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(name, data): (root/name).write_text(json.dumps(data, indent=2)+'\n')
head = command('git','rev-parse','HEAD')
assert command('git','rev-parse','origin/main') == a.expected_main, 'Fetch and pin current main first'
assert len(a.require_commit) >= 2, 'Supply the actual landed SOP51 and SOP52 commits'
for commit in a.require_commit:
    subprocess.run(['git','merge-base','--is-ancestor',commit,a.expected_main],cwd=repo,check=True)
product = ['app/Sources','app/Package.swift','app/reader','SOPHIA.md','app/scripts/make-app.sh']
assert not command('git','diff',a.expected_main,'--',*product), 'Product source differs from pinned main'
assert not root.exists(), 'Never reuse, empty, or reset a previous run directory'
root.mkdir(mode=0o700)
source = Path(__file__).resolve().parent
(root/'archive').mkdir()
for name in ['setup.py','supervise.py','main.swift']:
    shutil.copy2(source/name,root/'archive'/name)
package = repo/'app/build/Sophia.app'
mcp = package/'Contents/MacOS/sophia-mcp'; prompt = package/'Contents/Resources/SOPHIA.md'
assert mcp.is_file() and prompt.is_file(), 'Build the final release package first'
assert prompt.read_bytes() == (repo/'SOPHIA.md').read_bytes(), 'Packaged prompt mismatch'
binpath = Path(command('swift','build','--package-path','app','-c','release','--show-bin-path'))
assert mcp.read_bytes() == (binpath/'sophia-mcp').read_bytes(), 'Packaged MCP mismatch'
objects = sorted((binpath/'SophiaCore.build').glob('*.o')); assert objects
assert b'SOPHIA_UX_HARNESS' not in (package/'Contents/MacOS/Sophia').read_bytes(), 'Not a release app'
compile_args = ['swiftc','-O','-I',str(binpath/'Modules'),str(root/'archive/main.swift'),*map(str,objects),'-o',str(root/'caller')]
subprocess.run(compile_args,cwd=repo,check=True)
claude = a.claude.expanduser().absolute()
assert claude == (Path.home()/'.local/bin/claude'), 'Use the official installed executable, no alternate route'
version = command(claude,'--version')
record = {'repository':str(repo),'head':head,'productMain':a.expected_main,'requiredCommits':a.require_commit,
    'compileArguments':compile_args,'swiftVersion':command('swiftc','--version'),'cli':str(claude),
    'cliResolved':str(claude.resolve()),'cliVersion':version,'mcp':str(mcp),'prompt':str(prompt),
    'packageHashes':{str(f.relative_to(package)):sha(f) for f in package.rglob('*') if f.is_file()},
    'coreObjectHashes':{f.name:sha(f) for f in objects},'coreModuleHash':sha(binpath/'Modules/SophiaCore.swiftmodule'),
    'archiveHashes':{f.name:sha(f) for f in (root/'archive').iterdir()},'ordinaryRequestCap':1}
write('setup.json',record)
subprocess.run([str(root/'caller'),'prepare',str(root),str(mcp),str(prompt),str(claude)],cwd=repo,check=True)
notebook=root/'library/Source boundary'
write('before-files.json',{str(f.relative_to(notebook)):sha(f) for f in notebook.rglob('*') if f.is_file()})
print(root)
