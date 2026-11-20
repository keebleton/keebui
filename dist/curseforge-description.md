# KeebUI

I wanted a UI for WoW Forever that felt super clean without being overwhelming, so I made one. Flat look, no gloss, nothing to set up before it works, and no pile of features you'll never touch. It's a reskin of the stuff you actually look at, not a feature pack.

Your keybinds and whatever is on your bars don't get touched. KeebUI restyles the game's own buttons where they are, and saves bar positions as a separate Edit Mode layout called "KeebUI", so your old layout is still sitting there if you want it back.

## First login

You get a welcome screen asking which pieces you want. Nothing changes until you hit **Apply and reload**. If you only want the raid frames, only tick the raid frames.

## Raid and party frames

This is the part I care about most. I heal, and I built these for healing.

- Every debuff you can dispel shows in the middle of the frame with its stack count, and the whole frame gets tinted so you can't miss it.
- A settings window with a live preview, so you can set them up without being in a raid.
- Separate frame sizes and positions for 10, 20 and 40 player raids.
- You choose where other debuffs and your own buffs go, and how many show.
- Health text, name colour, a thin mana bar, bar colour, groups going down or across, sorting. All optional.
- Click casting on left, right and middle click, with or without Shift, Ctrl or Alt.
- Aggro outline, incoming rez, ready checks, and a marker when an enemy is casting at someone.

## The rest

- **Unit frames:** flat player, target, target of target and pet frames with class colours and incoming heals. If you'd rather keep Blizzard's frames, you can, and just have their health bars class-coloured.
- **Nameplates:** flat bars, class colours on enemy players, threat colours you can change, and a bigger plate on your target.
- **Action bars:** flat rounded buttons with keybind text you can actually read, three bars stacked bottom centre.
- **Cast bar and swing timer**, a scrollable quest list, a slim XP bar and flat tooltips.
- **Equipment sets:** gear that belongs to a saved set gets a coloured frame in your bags and bank so you don't vendor it, and you can deposit or withdraw a whole set at the bank in one click.

## Commands

- `/keebui` opens settings
- `/keebui frames` opens the raid and party frame settings
- `/keebui move` and `/keebui lock` to place things
- `/keebui restore` puts your old UI back

## Don't like it?

**Restore my old UI** puts back every game setting KeebUI changed, switches you back to the Edit Mode layout you were on, and turns all of it off.
