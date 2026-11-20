# KeebUI

A clean, flat interface for WoW Forever. One addon, no libraries, and nothing to configure before it works.

Your keybinds and what is on your action bars are never touched: the game's own buttons are restyled in place, and bar positions are stored as a separate Edit Mode layout called "KeebUI", so your previous layout is still there.

## First login

A welcome screen asks which pieces you want. Nothing about your interface changes until you press **Apply and reload**.

## What's in it

- **Unit frames**: flat player, target, target of target and pet frames with class colours, incoming heals and a combat glow. Or keep Blizzard's own frames and just have their health bars class-coloured.
- **Raid and party frames** built for healing, with a settings window and live preview:
  - cell size for 10, 20 and 40 player raids, groups down or across, sorting, health text, a thin mana bar
  - every debuff you can remove shown in the middle of the cell with its stack count, and the cell tinted
  - where other debuffs and your own buffs go, and how many
  - click casting on left, right and middle click, with or without Shift, Ctrl or Alt
  - aggro outline, incoming resurrections, ready checks, and a strip when an enemy is casting at someone
- **Nameplates**: flat bars, class colours for enemy players, threat colours you can edit, a larger plate for your target.
- **Action bars**: flat rounded buttons with readable keybind text, three bars stacked bottom centre.
- **Cast bar and swing timer**, a scrollable quest list, a slim experience bar and flat tooltips.
- **Equipment sets**: set gear is framed in your bags and bank in a colour you pick per set, and a whole set can be deposited or withdrawn at the bank with one click.

## Commands

- `/keebui` opens the settings
- `/keebui frames` opens the raid and party frame settings
- `/keebui move` and `/keebui lock` to place frames
- `/keebui restore` puts your old settings and layout back and switches KeebUI off

## Going back

**Restore my old UI** puts back every game setting KeebUI changed, switches Edit Mode to the layout you were on before, and turns all of KeebUI's pieces off.
