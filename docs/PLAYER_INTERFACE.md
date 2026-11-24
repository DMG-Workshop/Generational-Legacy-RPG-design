# The player interface

The player interface is mouse-first: a world you act in directly, with small windows over it that you arrange yourself. It is this game's own. The older mouse-driven RPGs it learns from are an influence on the ideas below (what the interface is *for*), and nothing more: the names, the art, the layout, the colours and the exact controls are all ours. This file is the plan. Nothing in it is built yet, and each slice below is its own pull request.

## The ideas

Every look and number here is ours to choose; the table names the idea, not a design to match.

**Windows over the world.** Everything the player opens (their figure and gear, their pack, their status, a shop, a skill list) is a small window over the world, not a full screen. A window has a face, a border and a title in this game's own look (the family's heraldry and the dynasty theme, not parchment scrolls copied from another game). Windows are dragged by their face, stay where they were left, and several are open at once. The world keeps running behind them. We call them **panes** in the code and the data, not gumps.

**The mouse does everything.**

| Action | The idea | Here |
|---|---|---|
| Walk | hold the right mouse button; the character runs toward the cursor | the same idea, in the open world |
| Look at something | single left click: its name floats over it | same |
| Use or open something | double left click | same (this replaces the Use button) |
| Context menu | right click on a thing in later clients, or a small popup of actions | a popup of that thing's actions |
| Pick up and move an item | left click and drag it, drop it on a window or on the ground | the same idea, between the pack, the figure pane and the world |
| Close a window | right click on it | the same idea |
| Speech | words float over a head and scroll into a journal | already so for villagers; add the journal |

The keyboard keeps its own bindings (`data/ui/input.json`); the mouse is added beside them, not instead of them.

**The heir's state is always on screen.** A small status pane with name, health, mana and a third bar for **carry weight against the limit** (`GameCarry.carried` over `GameCarry.capacity`; it turns to the warning colour once the heir is burdened), and a minimap of the nearby ground, each placed where this game's layout wants them.

**The figure pane** is the heir drawn in their gear, with a slot for each worn thing (head, body, hands, weapon, shield, feet) around them, a button for each of the other panes, and the title and name written under it. **The pack** is a pane with the carried items as icons on a grid, which can be dragged out, and a weight line.

## Slices

1. **The pane kit.** A `Pane` control in `ui/play/` (a draggable window with a face, border, title, close, and a memory of where it was left), its look in `data/ui/pane.json` (colours, border pieces, sizes; checked by `tools/check_data.gd`), and a pane layer on the open world screen that holds them. The existing map menu, shop, house, chronicle and skill panels open as panes over the world instead of full-screen overlays. Windows only: a phone keeps the full-screen panels (`docs/MOBILE.md`) until a touch version is designed.
2. **The mouse scheme** (built, except a popup of actions on a thing and remapping the mouse: hold right to walk, a click names, a double click uses, a right click closes a pane; `tests/test_game_mouse.gd`). Hold right to walk, single click for a name, double click to use, right click on a pane to close it, and a popup of actions on a thing. The Use button stays for touch. Remappable like the other actions (`WorldInput`).
3. **The status pane and the minimap** (built: status, nearby map and journal panes; `tests/test_game_hud.gd`). Status bars from the heir's health, mana and carry weight; the minimap from `GameWorldMap`'s sampling, centred on the heir; the journal pane from `GameSandbox.log` and the status line.
4. **The figure pane and the pack** (built, with item icons of our own in `data/art/icons.json`; a double click on the heir opens the figure pane). The figure from `SpriteArt.figure` and the worn items; the pack as icons. Drag and drop calls the same core functions the gear panel calls (`wear`, `drop`, buying and selling); the panes never compute a result.

The rules stay out of the interface, as always: the panes read dynasty state and call its methods. No slice changes any seeded result.

## Decided

- **The third bar is carry weight against the limit.** The heir has health and mana only, and no stamina, so the status pane's third bar shows what they carry against what they can carry.

## Open questions

- **Item icons.** The pack needs a small picture for each item. Items have none today (gear has looks for the figure only), so slice 4 starts with a set of icons of our own, in the existing art style (`docs/ART_STYLE.md`).
- **Art.** The face and border art is drawn from data like the rest of the art, not from files, and is designed for this game, not traced from another.
