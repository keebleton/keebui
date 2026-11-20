# KeebUI

A clean, flat interface for WoW Forever. One addon, no libraries, nothing to configure before it works.

Your keybinds and what is on your action bars are never touched: the game's own buttons are restyled in place, and bar positions are stored as a separate Edit Mode layout called "KeebUI", so your previous layout is still there.

## First login

A welcome screen asks which pieces you want. Nothing about your interface changes until you press **Apply and reload**. "Not now" leaves everything alone; `/keebui welcome` brings the screen back.

## What is in it

- **Unit frames**: player, target, target of target and pet, with class colours, incoming heals, a combat glow and a five-second-rule marker. Or keep Blizzard's own frames and just have their health bars class-coloured.
- **Party and raid frames**: built for healing, with a settings window and live preview (`/keebui frames`). Cell size for 10, 20 and 40 player raids, layout and sorting, health text, a thin mana bar, where debuffs and your buffs go. Every debuff you can remove sits in the middle of the cell with its stack count. Click casting on any mouse button, aggro rim, incoming resurrections, ready checks.
- **Nameplates**: flat bars, class colours for enemy players, threat colours you can edit, quest marker, larger target plate.
- **Action bars**: flat rounded buttons with readable keybind text, three bars stacked bottom centre.
- **Cast bar and swing timer**.
- **Tooltip**: flat to match.
- **Quest list, XP bar, bags**: scrollable quest list, slim XP/reputation bar, equipment-set gear framed in your bags and bank in a colour you pick per set, and one-click deposit or withdraw of a whole set at the bank.
- **Extras**: two trinket buttons with a bag pop-up, a raid tools bar (ready check, pull timer, marks) and a hold-to-open mark ring for your target.

## Commands

| Command | What it does |
| --- | --- |
| `/keebui` | Open the settings window |
| `/keebui frames` | Raid and party frame settings, with a preview |
| `/keebui click` | Click casting for raid and party frames |
| `/keebui move` / `/keebui lock` | Drag frames around, then lock them |
| `/keebui welcome` | Show the first-login screen again |
| `/keebui restore` | Put your old settings and layout back and switch KeebUI's pieces off |
| `/keebui errors` | Print anything that went wrong this session |

Keybinds for the trinket buttons and the mark ring are under Key Bindings > AddOns > KeebUI.

## Going back

**Restore my old UI** (in `/keebui`, General) puts back every game setting KeebUI changed, switches Edit Mode to the layout you were on before, and turns all of KeebUI's pieces off. The "KeebUI" layout stays in Edit Mode's list; delete it there if you no longer want it.
