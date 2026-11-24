# The Ultima Online interface

The player interface should feel like Ultima Online's, in both the look and the controls, on Windows first. This file is the plan. Nothing in it is built yet, and each slice below is its own pull request.

## What "UO" means here

From the way the 1997-2000 client worked. The numbers and exact looks are ours to choose; the shape is what we copy.

**Windows are gumps.** Everything the player opens (their paperdoll, their backpack, their status, a shop, a skill list) is a small window over the world, not a full screen. A gump has a parchment or stone face, an ornate border, a title and nothing else on top of it. Gumps are dragged by their face, stay where they were left, and several are open at once. The world keeps running behind them.

**The mouse does everything.**

| Action | UO | Here |
|---|---|---|
| Walk | hold the right mouse button; the character runs toward the cursor | same, in the open world |
| Look at something | single left click: its name floats over it | same |
| Use or open something | double left click | same (this replaces the Use button) |
| Context menu | right click on a thing in later clients, or a small popup of actions | a popup of that thing's actions |
| Pick up and move an item | left click and drag it, drop it on a gump or on the ground | same, between the backpack, the paperdoll and the world |
| Close a gump | right click on it | same |
| Speech | words float over a head and scroll into a journal | already so for villagers; add the journal |

The keyboard keeps its own bindings (`data/ui/input.json`); the mouse is added beside them, not instead of them.

**The status of the character is always on screen.** A status gump with name, health, mana and a third bar, small enough to sit in a corner, and a radar-style minimap of the nearby ground in the opposite corner.

**The paperdoll** is the character drawn in their gear, with a slot for each worn thing (head, body, hands, weapon, shield, feet) around them, a button for each of the other gumps, and the title and name written under it. **The backpack** is a gump with the carried items as icons on a grid, which can be dragged out, and a weight line.

## Slices

1. **The gump kit.** A `Gump` control in `ui/play/` (a draggable window with a face, border, title, close, and a memory of where it was left), its look in `data/ui/gump.json` (colours, border pieces, sizes; checked by `tools/check_data.gd`), and a gump layer on the open world screen that holds them. The existing map menu, shop, house, chronicle and skill panels open as gumps over the world instead of full-screen overlays. Windows only: a phone keeps the full-screen panels (`docs/MOBILE.md`) until a touch version is designed.
2. **The mouse scheme.** Hold right to walk, single click for a name, double click to use, right click on a gump to close it, and a popup of actions on a thing. The Use button stays for touch. Remappable like the other actions (`WorldInput`).
3. **The status gump and the minimap.** Status bars from the heir's health and mana; the minimap from `GameWorldMap`'s sampling, centred on the heir; the journal gump from `GameSandbox.log` and the status line.
4. **The paperdoll and the backpack.** The paperdoll from `SpriteArt.figure` and the worn items; the backpack from the pack as icons. Drag and drop calls the same core functions the gear panel calls (`wear`, `drop`, buying and selling); the gumps never compute a result.

The rules stay out of the interface, as always: the gumps read dynasty state and call its methods. No slice changes any seeded result.

## Open questions

- **A third bar.** UO had stamina. The heir has health and mana only. Either the third bar is left out, or something the game already has (the age of the heir, the carry weight against the limit) takes its place. Left out until decided.
- **Item icons.** The backpack needs a small picture for each item. Items have none today (gear has looks for the figure only), so slice 4 starts with a set of icons in the existing art style (`docs/ART_STYLE.md`).
- **Art.** The parchment and border art is drawn from data like the rest of the art, not from files.
