# KeebUI 0.9.3

- **Raid and party frames: removable debuffs no longer overlap.** With two or more debuffs you can remove, the large icon was still drawn behind the row of small ones. Now it is one or the other: a single debuff is drawn large, several are drawn small side by side.
- **Icons along the bottom of a frame sit above the mana bar** instead of on top of it, on frames that show one.
- **The raid tools bar hides in battlegrounds and arenas,** where it overlapped the score at the top of the screen. The mark ring keybind still works there.

New in 0.9.2:

- **Raid and party frames: fixed an error in combat.** 0.9.1 printed a "dispellable debuffs" error in chat during fights. That is gone.
- **A single removable debuff is now drawn large.** When a member has just one debuff you can remove, its icon is full size in the middle of their frame. With two or more, each is shown at half size side by side, as before.

New in 0.9.1:

- **Raid frames: cleaner outlines.** The red aggro outline is now drawn inside each raid cell, so neighbouring cells no longer cut it off. The white outline on your target sits exactly on the cell's edge.
- **Raid and party frames: tanks first.** Within each raid group, and in the party column, members are ordered tank, healer, then everyone else, by their assigned role. Turn it off under Layout in `/keebui frames`.
- **Battlegrounds: flag carriers.** The small enemy flag carrier frames now sit at the top of the screen beside the flag score. They used to end up underneath the right-hand action bars. Your KeebUI bar layout is rewritten once to do this, so anything KeebUI places (bars, bags, menu, tooltip) goes back to its default spot.
- **Pet frame** is half the width of your own frame.

New in 0.9.0:

- **Welcome screen.** On your first login KeebUI asks which pieces you want. Nothing about your interface changes until you press Apply.
- **Unit frames.** Flat player, target, target of target and pet frames with class colours, incoming heals and a combat glow. Or keep Blizzard's own frames and just have their health bars class-coloured.
- **Raid and party frames you can make your own.** A settings window with a live preview: cell size for 10, 20 and 40 player raids, groups down or across, sorting, health text, name colour, a thin mana bar, where debuffs and your buffs go, and bar colour.
  - Every debuff you can remove sits in the middle of the cell with its stack count, and tints the cell.
  - Click casting: bind left, right and middle click, with or without Shift, Ctrl or Alt, to a spell, to targeting, or to the menu.
  - Aggro outline, incoming resurrections, ready checks, and a strip when an enemy is casting at someone.
- **Nameplates.** Flat bars, class colours for enemy players (in battlegrounds too), threat colours you can edit, a larger plate for your target.
- **Action bars.** Flat rounded buttons with readable keybind text, three bars stacked bottom centre. Your keybinds and what is on your bars are never touched.
- **Cast bar and swing timer**, a scrollable quest list, a slim experience bar and flat tooltips.
- **Equipment sets.** Gear in a saved set is framed in your bags and bank, in a colour you pick per set, and a set can be deposited or withdrawn at the bank with one click.
- **Restore my old UI** puts back every game setting KeebUI changed and the Edit Mode layout you were on.
