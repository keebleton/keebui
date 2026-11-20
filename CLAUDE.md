# KeebUI

A flat UI reskin for WoW Forever (the 12.1 retail engine with vanilla content, TOC 16001). Keeb's own addon; he plays a
healing paladin and cares most about the raid frames. Scope: a functional reskin of core UI, not a feature pack. He has
removed extras more than once (flight timer, minimap drawer, damage meter skin, chat skin); when a custom skin looks off,
leaving the Blizzard element stock is preferred.

See [DEVELOPING.md](DEVELOPING.md) for layout, checks and releasing.

## How the code is laid out

Files load in the order in `KeebUI/KeebUI.toc`. `Core.lua` holds settings defaults, shared helpers (`ns.*`) and the
module registry: each feature registers `{ setting = "<db key>", init = fn }` and runs at login if its setting is on.
Nothing runs until the welcome screen (`Welcome.lua`) has been applied on a new install.

- `UnitFrames.lua` player / target / target of target / pet. `Group.lua` party and raid frames; `GroupOptions.lua` their
  settings window and mock preview. `Plates.lua` nameplates. `Bars.lua` + `Layout.lua` action buttons and the Edit Mode
  layout. `Cast.lua` cast bar, swing timer, combo points. `Chrome.lua` XP bar, bags, equipment-set marks, font.
  `Tracker.lua` quest list. `Skin.lua` tooltips. `Marks.lua` raid tools and the mark ring. `Bank.lua` sets at the bank.
  `Trinkets.lua` trinket buttons. `Options.lua` the main settings window and `/keebui`.

## Things this client enforces (learned the hard way)

- **Secret values.** In combat, health, power, aura fields, enemy identity in battlegrounds and "who is that enemy
  targeting" come back as values that cannot be compared or used in arithmetic, even against nil. They can be passed to
  widgets (`SetValue`, `SetText`, `SetFormattedText`, `SetStatusBarColor`, `SetAlphaFromBoolean`). Guard with
  `ns.IsSecret` / `ns.Clean`.
- **Auras cannot be read by addons in combat**, even on party members. Everything aura-related goes through the game's
  aura containers (`CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")`, `AddAuraGroup`,
  `AddAuraSlot`, `SetUnit`). Useful candidate filters: `includeDispelTypes`, `excludeDispelTypes`, `includeSpellIDs`,
  `excludeSpellIDs`, `isFromPlayerOrPlayerPet`, `maxDuration` (seconds; also drops untimed auras). The `PLAYER` word in
  a filter string alone does not restrict to your own casts. Container buttons can only be sized and placed inside
  `initializeFrame`; textures on them can be resized any time.
- **Taint.** Calling setters on Blizzard frames, replacing globals they call (`GetMinimapShape`) or skinning chat makes
  the game block its own actions in combat and blame KeebUI. Do not act inline inside `hooksecurefunc` on Blizzard code;
  defer with `C_Timer.After(0)`.
- **Protected frames** (unit buttons, group headers and their children) can only be created, sized, anchored or given
  attributes out of combat. Raid cells are all created at login. `SetRaidTarget` is Blizzard-only: marking goes through
  a `SecureActionButton` of type `raidtarget`. Unit buttons need a hidden helper button to open the right-click menu.
- **Raid groups** each have their own `SecureGroupHeader` (one header for the whole raid pours members into columns of
  five and breaks group alignment).
- New files and `.toc` changes need a full game restart; edits to existing files need `/reload`.

## Working without seeing the game

The game cannot be driven or seen from here. Keeb takes screenshots (`_forever_\Screenshots`, newest first) and they
are read from disk. Every change is syntax-checked with `python tests/run_tests.py` before it is reported; say plainly
when something is untested in game. Errors are kept per session in `KeebUIDB.errors` / `gameErrors` (`/keebui errors`).

## Writing for players

`README.md` and `CHANGELOG.md` are read by players on CurseForge: plain English, what changed for them, no internals.
