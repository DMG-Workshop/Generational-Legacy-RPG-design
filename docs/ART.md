# Battle art

The battle screen draws the hero, the companions and the foes as pixel-art sprites. The sprites are kept as
text grids in `data/art/` and turned into textures by `ui/play/sprite_art.gd` the first time they are drawn.
There are no image files: a sprite is data, reviewed in a diff like any other. Anything without art keeps
the old coloured block, so new content still shows before its art lands.

The same sprites are meant for the later isometric pixel-art version of the game.

## Files

| File | Holds |
|------|-------|
| `data/art/classes.json` | One figure per class: `{"sprites": {class_id: SPRITE}}` |
| `data/art/races.json` | Each race's colours and layers: `{"races": {race_id: RACE}}` |
| `data/art/creatures.json` | One sprite per creature id in `data/creatures/creatures.json`, bosses included |
| `data/art/shirts.json` | The shirt colours a hero or companion can wear: `{"shirts": [{"id", "name", "color"}]}` |

`tests/test_game_art.gd` checks that the data is sound and that every creature, class and race has art.
`tools/art_sheet.gd` draws all of it on one sheet:

```bash
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/creatures.png
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/heroes.png what=heroes
```

## The format

```json
{"size": [w, h], "palette": {"k": "#1b1626", "g": "#6abf4b"}, "rows": ["..kk..", "..."]}
```

- `rows` has exactly `h` strings of exactly `w` characters. `.` is clear. Any other character is a one-letter
  key of the sprite's own `palette`.
- Reserved keys are filled in when the game draws the sprite and never go in a palette: `S` skin, `s` skin
  shade, `H` hair, `h` hair shade (from the race), `C` shirt colour and `c` its shade (from the figure's
  shirt). Only class figures and race layers use them.

## Heroes and companions

A hero or companion is drawn in three layers: the race's `under` layer, the class figure, and the race's
`over` layer. The race's colours fill the figure's `S`/`s`/`H`/`h` pixels, and the figure's shirt fills `C`/`c`.

Everyone wears a shirt from `shirts.json`. Until the player chooses one, the shirt is picked from who the
figure is (an heir's id and name, a companion's id and name), never from the game's dice, so the same person
always wears the same shirt. The Looks button on the life screen opens `ui/play/looks_panel.gd`, where the
player chooses the heir's and each companion's shirt. `GameDynasty.set_shirt` keeps the choice as `shirt`
on the heir or on the party member. It is saved only once something is chosen, so older saves and the golden
digests are unchanged.

- **Class figures** are exactly 24 x 40 and face right, towards the foes. Rows 0-3 are headroom for hats.
  Rows 4-16 are the shared head: every class keeps the same face pixels (skin, eye and nose at x 10-18,
  y 9-16), so the race layers line up on every class. Headgear may cover the top and back of the head, but
  never the face.
- **Races** set `skin`, `skin_shade`, `hair` and `hair_shade`, and may add full 24 x 40 `under` and `over`
  layers with their own `palette`. `under` is for things behind the body (tails, horns behind a hood) and
  `over` for things in front (beards, tusks, snouts, ears).

## Creatures

Creatures face left, towards the party. A normal creature is at most 40 x 40, usually on a canvas 32 wide.
A boss is at most 64 x 64. A sprite's main colour is the creature's `color` in `creatures.json`, the colour
players knew from the blocks. Element accents are fire orange and yellow, frost icy blue, shadow purple with
glowing eyes, lightning yellow sparks, earth stone browns, and nature greens.

## Style

- Clean pixel art like a 16-bit JRPG battle sprite, with a 1-pixel outline in `#1b1626`.
- Light comes from the top left: 2 or 3 shades per material, and about 12 colours at most.
- No stray single pixels, dithering or anti-aliasing. The silhouette should read at a glance at 3x scale on
  the game's dark background (`#14121c`).
- Leave a 1-pixel clear margin on every side. Figures stand on the bottom rows.

## How it is drawn

`SpriteArt` scales each grid up by whole pixels (`UPSCALE`, 4) before the screen fits it into its box. The
screen then shrinks it smoothly, so every pixel stays the same size whatever the box. Each texture is made
once and kept.

The battle screen keeps a clear body under every sprite, which takes taps, holds and flashes as the old
blocks did. A foe's level sits on a dark tag, so it reads over any sprite.
