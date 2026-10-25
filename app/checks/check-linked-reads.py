#!/usr/bin/env python3
"""Direct MCP existing-only read regressions; disposable developer fixtures, no provider."""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

binary = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.build/debug/sophia-mcp').resolve()
root = pathlib.Path(tempfile.mkdtemp(prefix='sophia-linked-mcp-'))
library = root / 'library'
source, target = library / 'Source', library / 'Target'

def request(name, arguments):
    return {'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call', 'params': {'name': name, 'arguments': arguments}}

def exchange(book, messages):
    result = subprocess.run([str(binary), str(book), 's-linked-fixture'], input=''.join(json.dumps(m) + '\n' for m in messages), text=True, capture_output=True, timeout=15, check=True)
    return [json.loads(line) for line in result.stdout.splitlines()]

def tool(book, name, **arguments):
    return exchange(book, [request(name, arguments)])[0]['result']['content'][0]['text']

def tree():
    return {str(p.relative_to(root)): ('link:' + str(p.readlink()) if p.is_symlink() else 'directory' if p.is_dir() else p.read_bytes()) for p in root.rglob('*')}

def unchanged_read(arguments, expected=None, forbidden='OUTSIDE_CANARY'):
    before = tree()
    text = tool(source, 'read_page', **arguments)
    assert tree() == before, ('read mutated fixture', arguments)
    if expected is not None:
        assert expected in text, (expected, text)
    assert forbidden not in text, text
    return text

for book in (source, target):
    tool(book, 'write_page', title=book.name, content='Opening.\n\n## Evidence\nTARGET_BODY\n\n## Later\nLATER_BODY')
links = library / '.sophia' / 'links.jsonl'
link = {'id': 'l-1', 'at': '2026-10-25T13:00:00Z', 'by': 'person', 'from': {'notebook': 'Source'}, 'to': {'notebook': 'Target', 'page': 'target.md'}, 'reason': 'Synthetic developer fixture'}
links.write_text(json.dumps(link) + '\n')
args = {'notebook': 'Target', 'file': 'target.md'}
unchanged_read(args, 'TARGET_BODY')
section = unchanged_read(dict(args, section='Evidence'), 'TARGET_BODY')
assert 'LATER_BODY' not in section
unchanged_read({'file': 'source.md'}, '# Source')
unchanged_read({}, 'source.md')
for name in ('../Target', 'Target/../Target', 'Target\\other'):
    assert 'TARGET_BODY' not in unchanged_read(dict(args, notebook=name))
for name in ('../target.md', '/target.md', 'target.md/..'):
    assert 'TARGET_BODY' not in unchanged_read(dict(args, file=name))

# Corrupt source metadata must not be repaired before the privacy decision.
metadata = source / 'notebook.json'
saved = metadata.read_bytes()
for invalid in (b'{', b'{"chapters":[],"unfiled":[],"separate":"unknown"}'):
    metadata.write_bytes(invalid)
    text = unchanged_read(args, 'unavailable')
    assert 'TARGET_BODY' not in text
    before = tree()
    exchange(source, [{'jsonrpc': '2.0', 'id': 2, 'method': 'initialize'}, {'jsonrpc': '2.0', 'id': 3, 'method': 'tools/list'}])
    assert tree() == before
metadata.write_bytes(saved)

# Missing destination stays missing; no defaults, folders, locks or journals.
removed = root / 'removed-target'
shutil.move(target, removed)
unchanged_read(args, 'no longer available')
assert not target.exists()
shutil.move(removed, target)

# Permission and separation are checked from current saved metadata/links.
links.write_text(json.dumps(dict(link, by='sophia')) + '\n')
unchanged_read(args, 'confirmed link')
links.write_text(json.dumps(link) + '\n')
target_meta = target / 'notebook.json'
saved_target = target_meta.read_bytes()
obj = json.loads(saved_target); obj['separate'] = True
target_meta.write_text(json.dumps(obj))
unchanged_read(args, 'confirmed link')
target_meta.write_bytes(b'{')
unchanged_read(args, 'no longer available')
target_meta.write_bytes(saved_target)

links.write_text(json.dumps(link) + '\n' + json.dumps(dict(link, id='l-2', to={'notebook': 'Target', 'page': 'outside.md'})) + '\n')

# No outside bytes through notebook, pages-directory, page or metadata symlinks.
canary = root / 'canary'; (canary / 'pages').mkdir(parents=True)
(canary / 'notebook.json').write_text(json.dumps({'chapters': [], 'unfiled': ['outside.md']}))
(target / 'pages' / 'outside.md').write_text('---\ntitle: OUTSIDE_CANARY\n---\nOUTSIDE_CANARY')
(canary / 'pages' / 'target.md').write_text('---\ntitle: OUTSIDE_CANARY\n---\nOUTSIDE_CANARY')
for path, outside in ((target, canary), (target / 'pages', canary / 'pages'), (target / 'pages' / 'target.md', canary / 'pages' / 'target.md'), (target_meta, canary / 'notebook.json')):
    held = path.with_name(path.name + '-held')
    path.rename(held); path.symlink_to(outside, target_is_directory=outside.is_dir())
    unchanged_read(args)
    if path == target_meta:
        # Following outside metadata would list/read this distinct local canary.
        unchanged_read({'notebook': 'Target', 'file': 'outside.md'})
        assert 'TARGET_BODY' not in unchanged_read(args)
    path.unlink(); held.rename(path)

# Historical duplicate references remain readable without rewriting metadata.
saved_meta = target_meta.read_bytes()
dup = json.loads(saved_meta); dup['unfiled'] = ['target.md', 'target.md']
target_meta.write_text(json.dumps(dup))
unchanged_read(args, 'TARGET_BODY')
target_meta.write_bytes(saved_meta)

# Duplicate chapter arguments must remain readable through the strict reader.
tool(source, 'set_chapter', chapter='Evidence', pages=['source.md', 'source.md'])
assert json.loads((source / 'notebook.json').read_text())['chapters'][0]['pages'] == ['source.md']
unchanged_read({'file': 'source.md'}, '# Source')
legal = library / 'C\\C++ notes'
tool(legal, 'write_page', title='Legal filename', content='LEGAL_BODY')
assert 'LEGAL_BODY' in tool(legal, 'read_page', file='legal-filename.md')

# A single tool process must retain ordinary mutations and see their result on next read.
messages = [request('read_page', {'file': 'source.md'}), request('write_page', {'title': 'Fresh', 'content': 'FRESH_WRITE'}), request('read_page', {'file': 'fresh.md'})]
replies = exchange(source, messages)
assert 'Source' in replies[0]['result']['content'][0]['text']
assert 'Saved as a new page' in replies[1]['result']['content'][0]['text']
assert 'FRESH_WRITE' in replies[2]['result']['content'][0]['text']
print(json.dumps({'passed': True, 'fixture': str(root), 'cases': 'full/section/local/list, invalid IDs, corrupt source/target, missing, provisional/separate, symlink canaries, read-write-read', 'providerInvoked': False}))
