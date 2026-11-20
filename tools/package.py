"""Build dist/KeebUI-<version>.zip by hand: just the KeebUI folder, nothing else.
Double-click 'Package for CurseForge.bat'. (Releases normally build themselves: see DEVELOPING.md.)"""
import os, re, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "KeebUI")
DIST = os.path.join(ROOT, "dist")
os.makedirs(DIST, exist_ok=True)

toc = open(os.path.join(ADDON, "KeebUI.toc"), encoding="utf-8").read()
version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
listed = [l.strip() for l in toc.splitlines() if l.strip().endswith(".lua")]
missing = [f for f in listed if not os.path.exists(os.path.join(ADDON, f))]
if missing:
    raise SystemExit("files listed in the .toc are missing: " + ", ".join(missing))

out = os.path.join(DIST, f"KeebUI-{version}.zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in os.walk(ADDON):
        for name in sorted(files):
            if name.endswith((".lua", ".toc", ".xml", ".tga", ".blp", ".ogg", ".ttf")):
                full = os.path.join(folder, name)
                z.write(full, os.path.join("KeebUI", os.path.relpath(full, ADDON)))
print("built", out)
with zipfile.ZipFile(out) as z:
    for n in z.namelist():
        print("   ", n)
