# Developing KeebUI

Notes for working on the addon. The player-facing description is [README.md](README.md); project notes for Claude
Code are in [CLAUDE.md](CLAUDE.md).

## What's where

- `KeebUI/` is the addon. The folder name must stay `KeebUI`: the saved data (`KeebUIDB`) and the media paths depend on
  it, whatever the zip is called.
- `tests/run_tests.py` checks every Lua file loads (Lua 5.1 through `lupa`), that `KeebUI.toc` lists exactly the files
  that exist, and that `CHANGELOG.md` is for the version in the `.toc`. The addon cannot be run outside the game, so
  this catches typos, not behaviour: behaviour is checked in game.
- `tools/`: `setup_pc.py` (links the addon into WoW), `package.py` (a zip by hand).
- `Set up this PC.bat`: links the addon into WoW and runs the checks.
- `Package for CurseForge.bat`: builds `dist/KeebUI-<version>.zip`. Zips in `dist/` aren't committed.
- `dist/curseforge-description.md`: the CurseForge page text.

## Setting up a computer

1. Install World of Warcraft (Forever), [Git](https://git-scm.com/download/win),
   [GitHub Desktop](https://desktop.github.com/) and [Python](https://www.python.org/downloads/) (tick
   "Add python.exe to PATH").
2. Clone the repository in GitHub Desktop.
3. **Close WoW**, then double-click `Set up this PC.bat`. It links the addon into
   `_forever_\Interface\AddOns\KeebUI` (so edits show after `/reload`). A regular KeebUI folder already there is first
   copied into this repo if it is newer (so nothing edited in place is lost), then moved to
   `Interface\KeebUI-backups`.
4. Don't let the CurseForge app (or WowUp) install or update KeebUI on a computer you develop on: it replaces the link
   with its own copy.

## Releasing

Releases are automatic: pushing a version tag runs `.github/workflows/release.yml` on GitHub. It checks the tag matches
the addon's version, runs the checks, and then the [BigWigs packager](https://github.com/BigWigsMods/packager) (settings
in `.pkgmeta`) builds `KeebUI-v<version>.zip` with just the `KeebUI` folder, uploads it to CurseForge (the project id
in the `.toc`) with `CHANGELOG.md` as its release notes, and makes the GitHub release with `release.json`, which WowUp
installs from.

1. Bump `## Version` in `KeebUI/KeebUI.toc`, replace `CHANGELOG.md` with this version's notes (plain English, for
   players: CurseForge shows it; the first line must be `# KeebUI <version>`), run the checks, commit and push.
2. Tag that commit `v<version>` (for example `v0.9.1`) and push the tag. In GitHub Desktop: History, right-click the
   commit, Create Tag, then Push origin.
3. Watch it on GitHub under Actions (about two minutes). CurseForge reviews every upload.

One-time setup:

- Create the project on CurseForge and put its id in `KeebUI/KeebUI.toc` as `## X-Curse-Project-ID: <id>`.
- A CurseForge API token (CurseForge account settings, API tokens) saved on GitHub as the repository secret
  `CF_API_KEY` (Settings > Secrets and variables > Actions).

Without those the release still reaches GitHub and WowUp, but not CurseForge. WowUp users install from the
repository's GitHub URL.

By hand, if ever needed: double-click `Package for CurseForge.bat` and upload the zip on CurseForge.
