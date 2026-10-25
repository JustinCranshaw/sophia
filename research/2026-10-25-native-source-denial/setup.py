#!/usr/bin/env python3
"""Prepare one fresh SOP53 run. Never invokes the model; supervise.py is a separate explicit step."""
import argparse, hashlib, json, os, shutil, struct, subprocess
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
assert len(a.require_commit) >= 3, 'Supply the actual landed SOP51, SOP52 and SOP54 commits'
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
# make-app.sh re-signs the packaged copy. Never alter either actual executable.
subprocess.run(['codesign','--verify','--strict',str(mcp)],check=True)
comparison = root/'signature-comparison'; comparison.mkdir()
def unsigned_identity(path, name):
    copy = comparison/name; shutil.copy2(path,copy)
    subprocess.run(['codesign','--remove-signature',str(copy)],check=True)
    data = bytearray(copy.read_bytes()); original_hash = sha(copy)
    assert struct.unpack_from('<I',data)[0] == 0xfeedfacf, 'Expected native 64-bit Mach-O'
    offset = 32; uuid = None; linkedit_size = None
    for _ in range(struct.unpack_from('<I',data,16)[0]):
        kind,size = struct.unpack_from('<II',data,offset)
        assert size >= 8 and offset+size <= len(data)
        if kind == 0x1b: uuid = bytes(data[offset+8:offset+24]).hex()
        if kind == 0x19 and bytes(data[offset+8:offset+24]).rstrip(b'\0') == b'__LINKEDIT':
            linkedit_size = struct.unpack_from('<Q',data,offset+32)[0]
            # codesign removal retains signing allocation in LINKEDIT's VM size.
            # Normalize only this non-content allocation field; all other bytes must match.
            struct.pack_into('<Q',data,offset+32,0)
        offset += size
    assert uuid and linkedit_size is not None
    return data, {'uuid':uuid,'rawHash':sha(path),'strippedHash':original_hash,
                  'linkeditVMSize':linkedit_size,'normalizedHash':hashlib.sha256(data).hexdigest()}
packaged_bytes, packaged_identity = unsigned_identity(mcp,'packaged-mcp')
product_bytes, product_identity = unsigned_identity(binpath/'sophia-mcp','release-product-mcp')
assert packaged_identity['uuid'] == product_identity['uuid'] and packaged_bytes == product_bytes, 'MCP code/content mismatch'
write('mcp-identity.json',{'packaged':packaged_identity,'releaseProduct':product_identity,
      'normalization':'signature removed on owned copies; only LINKEDIT VM allocation zeroed; remaining bytes exact',
      'packagedSignatureVerified':True})
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
