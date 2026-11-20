"""Checks that can be made without the game (run by the release workflow and by hand):

1. every Lua file in KeebUI/ loads as Lua 5.1 (catches typos and broken edits)
2. KeebUI.toc lists exactly the Lua files that exist
3. CHANGELOG.md is for the version in the .toc

The addon itself cannot be run outside the game, so this is not a test of behaviour.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.environ.get("KEEBUI_DIR") or os.path.join(ROOT, "KeebUI")


def main():
    try:
        import lupa
    except ImportError:
        print("lupa is not installed: pip install lupa")
        return 1
    lua = lupa.LuaRuntime()
    load = lua.eval("function(source, name) local fn, err = loadstring(source, name) return err end") \
        if lua.eval("loadstring ~= nil") else lua.eval("function(source, name) local fn, err = load(source, name) return err end")

    problems = []
    files = sorted(f for f in os.listdir(ADDON) if f.endswith(".lua"))
    for name in files:
        source = open(os.path.join(ADDON, name), encoding="utf-8").read()
        err = load(source, "=" + name)
        if err:
            problems.append(f"{name}: {err}")

    toc = open(os.path.join(ADDON, "KeebUI.toc"), encoding="utf-8").read()
    listed = [line.strip() for line in toc.splitlines() if line.strip().endswith(".lua")]
    for name in listed:
        if name not in files:
            problems.append(f"KeebUI.toc lists {name}, which does not exist")
    for name in files:
        if name not in listed:
            problems.append(f"{name} exists but is not listed in KeebUI.toc")
    if len(listed) != len(set(listed)):
        problems.append("KeebUI.toc lists a file twice")

    version = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not version:
        problems.append("KeebUI.toc has no ## Version line")
    else:
        first = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").readline().strip()
        if first != f"# KeebUI {version.group(1)}":
            problems.append(f"CHANGELOG.md starts with '{first}', expected '# KeebUI {version.group(1)}'")

    if problems:
        print("FAILED")
        for p in problems:
            print("  " + p)
        return 1
    print(f"OK: {len(files)} Lua files load, the .toc matches them, the changelog is for {version.group(1)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
