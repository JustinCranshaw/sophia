#!/usr/bin/python3
# Transparent temporary protocol capture; actual packaged handler receives identical bytes.
import subprocess,sys,threading,os,time
from pathlib import Path
p=subprocess.Popen([str(Path(__file__).with_name('packaged-sophia-mcp')),*sys.argv[1:]],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=sys.stderr.buffer)
with open('/tmp/sophia-package-probe/mcp-owned-pids','a') as f:f.write(str(p.pid)+'\n')
def forward_input():
    for line in sys.stdin.buffer:
        with open('/tmp/sophia-package-probe/mcp-in.jsonl','ab') as f:f.write(line)
        try:p.stdin.write(line);p.stdin.flush()
        except BrokenPipeError:return
    p.stdin.close()
threading.Thread(target=forward_input,daemon=True).start()
for line in p.stdout:
    with open('/tmp/sophia-package-probe/mcp-out.jsonl','ab') as f:f.write(line)
    sys.stdout.buffer.write(line);sys.stdout.buffer.flush()
sys.exit(p.wait())
