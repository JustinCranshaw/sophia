#!/usr/bin/env python3
"""Persistent local MCP root-page regressions. Synthetic fixtures; no provider requests."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

binary = Path(sys.argv[1] if len(sys.argv) > 1 else '.build/debug/sophia-mcp').resolve()
with tempfile.TemporaryDirectory(prefix='sophia-root-mcp-') as directory:
    book = Path(directory) / 'Notebook'
    process = subprocess.Popen([str(binary), str(book), 'root-regression'], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    sequence = 0
    def call(name, **arguments):
        global sequence
        sequence += 1
        message = {'jsonrpc': '2.0', 'id': sequence, 'method': 'tools/call',
                   'params': {'name': name, 'arguments': arguments}}
        process.stdin.write(json.dumps(message) + '\n')
        process.stdin.flush()
        response = json.loads(process.stdout.readline())
        assert response['id'] == sequence, response
        return response['result']['content'][0]['text']
    try:
        assert 'Saved' in call('write_page', title='A page', content='Original ordinary content.')
        metadata = book / 'notebook.json'
        meta = json.loads(metadata.read_text())
        # The app reserves a real introduction while this MCP writer stays alive.
        meta['overview'] = 'intro.md'
        meta['pageProperties'] = {'intro.md': {'role': 'notebook', 'scope': 'notebook'}}
        (book / 'pages/intro.md').write_text('---\ntitle: "Notebook"\n---\nOriginal intro.\n')
        metadata.write_text(json.dumps(meta))
        assert 'intro.md' in call('read_page')
        result = call('write_page', page='intro.md', title='Notebook', content='Revised intro.', chapter='Chapter 1: Fixed attachment')
        assert result.startswith('Revised intro.md.'), result
        assert 'Revised intro.' in (book / 'pages/intro.md').read_text()
        after = metadata.read_bytes()
        result = call('set_chapter', chapter='Chapter 1: Fixed attachment', pages=['intro.md'])
        assert result.startswith('Not changed: introductions'), result
        assert metadata.read_bytes() == after
        assert 'now has' in call('set_chapter', chapter='Chapter 1: Ordinary pages', pages=['a-page.md'])
        print('Persistent MCP checks passed: fresh root target, truthful revision with chapter, fixed attachments, ordinary filing.')
    finally:
        process.stdin.close()
        process.wait(timeout=5)
