#!/usr/bin/env python3
"""Compile the actual presentation mapping and focused cases; no model or GUI."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
subprocess.run(["swift", "build", "--package-path", "app", "--product", "Sophia"], cwd=root, check=True)
build = Path(subprocess.check_output(["swift", "build", "--package-path", "app", "--show-bin-path"], cwd=root, text=True).strip())
with tempfile.TemporaryDirectory(prefix="sophia-row-checks-") as directory:
    scratch = Path(directory)
    main = scratch / "main.swift"
    main.write_text(Path(__file__).with_name("row-checks.swift").read_text())
    command = ["swiftc", "-swift-version", "5", "-I", str(build / "Modules"),
               str(root / "app/Sources/Sophia/ConversationRows.swift"), str(main)]
    command += [str(path) for path in sorted((build / "SophiaCore.build").glob("*.o"))]
    command += ["-o", str(scratch / "checks")]
    subprocess.run(command, cwd=root, check=True)
    subprocess.run([str(scratch / "checks")], cwd=root, check=True)
