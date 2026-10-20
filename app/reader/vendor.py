#!/usr/bin/env python3
"""Refresh the reader's self-contained browser distributions from assets.lock.json.

No npm installation is needed. Reader packages are copied from their published
distributions. Packages with a "bundle" (the page editor's CodeMirror, and abcjs's
renderer for music) are unpacked into a temporary node_modules and prebundled into
one script per bundle with the locked esbuild binary ("tool": "esbuild"), so the app
loads no ES modules from file:// and building the app needs no Node. Every archive
is verified first.
To use already downloaded tarballs, pass their directory (files named
sophia-<name>-<version>.tgz, with "@" dropped and "/" as "-").
"""
import base64
import hashlib
import io
import json
from pathlib import Path
import platform
import subprocess
import sys
import tarfile
import tempfile

root = Path(__file__).resolve().parent
destination = root.parent / "Sources/SophiaReader/Reader/vendor"
destination.mkdir(parents=True, exist_ok=True)
files = {
    "markdown-it": {"dist/browser/markdown-it.umd.min.js": "markdown-it.min.js", "LICENSE": "markdown-it.LICENSE"},
    "markdown-it-texmath": {"texmath.js": "texmath.js", "license.txt": "texmath.LICENSE"},
    "katex": {"dist/katex.min.js": "katex.min.js", "dist/katex.min.css": "katex.min.css", "LICENSE": "katex.LICENSE"},
    "dompurify": {"dist/purify.min.js": "purify.min.js", "LICENSE": "dompurify.LICENSE"},
}
# Each bundle: its entry file here, and its output and license file in vendor/.
bundles = {
    "editor": ("editor-entry.js", "codemirror.min.js", "codemirror.LICENSE"),
    "music": ("music-entry.js", "abcjs.min.js", "abcjs.LICENSE"),
}
esbuild_platform = {"arm64": "darwin-arm64", "x86_64": "darwin-x64"}[platform.machine()]


def fetch(asset):
    if len(sys.argv) > 1:
        name = asset["name"].replace("@", "").replace("/", "-")
        data = (Path(sys.argv[1]) / f"sophia-{name}-{asset['version']}.tgz").read_bytes()
    else:
        data = subprocess.check_output(["curl", "-fLsS", "--max-time", "60", asset["url"]])
    algorithm, digest = asset["integrity"].split("-", 1)
    if base64.b64encode(hashlib.new(algorithm, data).digest()).decode() != digest:
        raise SystemExit(f"Integrity check failed: {asset['name']}")
    return tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")


with tempfile.TemporaryDirectory() as work:
    work = Path(work)
    esbuild = None
    licenses = {name: [] for name in bundles}
    for asset in json.loads((root / "assets.lock.json").read_text()):
        if asset.get("tool") == "esbuild":
            if not asset["name"].endswith("/" + esbuild_platform):
                continue
            with fetch(asset) as archive:
                esbuild = work / "esbuild"
                esbuild.write_bytes(archive.extractfile("package/bin/esbuild").read())
                esbuild.chmod(0o755)
            version = subprocess.check_output([esbuild, "--version"], text=True).strip()
            if version != asset["version"]:
                raise SystemExit(f"esbuild reports {version}, locked {asset['version']}")
        elif asset.get("bundle") in bundles:
            package = work / "node_modules" / asset["name"]
            package.mkdir(parents=True)
            with fetch(asset) as archive:
                # Strip the archive's "package/" prefix; refuse links and paths outside the package.
                members = [m for m in archive.getmembers() if m.name.startswith("package/") and m.isfile()]
                for m in members:
                    m.name = m.name[len("package/"):]
                archive.extractall(package, members=members, filter="data")
            license_file = next((package / n for n in ("LICENSE", "LICENSE.md", "license") if (package / n).exists()), None)
            if license_file is None:
                raise SystemExit(f"No license file in {asset['name']}")
            licenses[asset["bundle"]].append(f"{asset['name']} {asset['version']}\n\n{license_file.read_text().strip()}\n")
        else:
            with fetch(asset) as archive:
                for source, target in files[asset["name"]].items():
                    (destination / target).write_bytes(archive.extractfile("package/" + source).read())
                if asset["name"] == "katex":
                    fonts = destination / "fonts"
                    fonts.mkdir(exist_ok=True)
                    for member in archive.getmembers():
                        if member.name.startswith("package/dist/fonts/") and member.name.endswith(".woff2"):
                            (fonts / Path(member.name).name).write_bytes(archive.extractfile(member).read())
        print(f"Vendored {asset['name']} {asset['version']} (integrity verified)")

    if esbuild is None:
        raise SystemExit(f"No locked esbuild for {esbuild_platform}")
    for name, (entry_name, output, license_name) in bundles.items():
        entry = work / entry_name
        entry.write_bytes((root / entry_name).read_bytes())
        subprocess.run([esbuild, entry, "--bundle", "--minify", "--format=iife", "--target=safari17",
                        "--legal-comments=none", f"--outfile={destination / output}"], check=True, cwd=work)
        (destination / license_name).write_text("\n\n".join(licenses[name]))
        print(f"Bundled vendor/{output}")
