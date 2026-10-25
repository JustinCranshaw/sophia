#!/usr/bin/env python3
"""Drive only the debug app's native UX; retain every command, UI tree and screenshot."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=Path)
parser.add_argument("action", choices=["launch", "inspect", "menu", "press", "set", "key", "type", "click", "hover", "scroll", "resize"])
parser.add_argument("--id", type=int)
parser.add_argument("--text")
parser.add_argument("--code", type=int)
parser.add_argument("--modifiers", nargs="*", default=[])
parser.add_argument("--width", type=float)
parser.add_argument("--height", type=float)
parser.add_argument("--x", type=float)
parser.add_argument("--y", type=float)
parser.add_argument("--dy", type=float)
parser.add_argument("--return-gap", type=float, default=21600,
                    help="Launch-only return threshold; use 60 for an explicitly accelerated return exercise")
parser.add_argument("--without-claude", action="store_true",
                    help="Launch-only debug fault injection: exercise the real missing-install UI")
args = parser.parse_args()
root = args.directory.resolve()
root.mkdir(parents=True, exist_ok=True)
if args.action == "launch":
    binary = Path(__file__).resolve().parents[1] / "build/Sophia.app/Contents/MacOS/Sophia"
    if not binary.is_file() or b"SOPHIA_UX_HARNESS" not in binary.read_bytes():
        raise SystemExit("Build the debug bundle first: app/scripts/make-app.sh debug")
    pid_file = root / "pid"
    if pid_file.exists():
        try:
            os.kill(int(pid_file.read_text()), 0)
        except (ValueError, ProcessLookupError):
            pass
        else:
            raise SystemExit("This UX directory already has a running app; quit it before relaunching.")
    # Commands use transient accessibility IDs and must never survive a relaunch.
    for pending in (root / "commands").glob("*.json"):
        pending.unlink()
    env = os.environ.copy()
    for key in list(env):
        if key.startswith("SOPHIA_SNAPSHOT"):
            env.pop(key)
    env.update(SOPHIA_UX_HARNESS=str(root), SOPHIA_LIBRARY=str(root / "library"))
    env["SOPHIA_RETURN_GAP"] = str(args.return_gap)
    if args.without_claude:
        env["SOPHIA_UX_NO_CLAUDE"] = "1"
    else:
        env.pop("SOPHIA_UX_NO_CLAUDE", None)
    with (root / "app.log").open("ab") as log:
        process = subprocess.Popen([str(binary)], env=env, stdout=log, stderr=log, start_new_session=True)
    (root / "pid").write_text(str(process.pid))
    print(json.dumps({"pid": process.pid, "directory": str(root)}))
    raise SystemExit(0)
command = {k: v for k, v in vars(args).items() if k not in ("directory", "return_gap", "without_claude") and v is not None}
if args.action == "key" and not args.text:
    characters = {36: "\r", 53: "\x1b", 126: "\uf700", 125: "\uf701",
                       123: "\uf702", 124: "\uf703", 116: "\uf72c", 121: "\uf72d",
                       115: "\uf729", 119: "\uf72b", 51: "\x7f", 48: "\t"}
    code = args.code if args.code is not None else 36
    if code not in characters:
        parser.error("This key code requires --text with its actual character")
    command["text"] = characters[code]
name = f"{time.time_ns()}-{uuid.uuid4().hex[:6]}.json"
folder = root / "commands"
folder.mkdir(exist_ok=True)
temporary = folder / (name + ".tmp")
temporary.write_text(json.dumps(command))
temporary.rename(folder / name)
deadline = time.monotonic() + 25
result = root / "results" / name
while time.monotonic() < deadline:
    if result.exists():
        response = json.loads(result.read_text())
        # Record the exact submitted UI action with its result.
        response["command"] = command
        result.write_text(json.dumps(response, indent=2))
        readable = dict(response)
        readable["tree"] = [{k: v for k, v in row.items() if k not in ("class", "frame", "depth")}
                            for row in response["tree"]
                            if row.get("label") or row.get("title") or row.get("value")
                            or row.get("role") in ("AXTextField", "AXTextArea", "AXButton", "AXScrollArea")]
        print(json.dumps({"result": str(result), **readable}, indent=2))
        break
    time.sleep(0.1)
else:
    (folder / name).unlink(missing_ok=True)
    raise SystemExit("No UX response within 25 seconds; inspect app.log, do not bypass the UI.")
