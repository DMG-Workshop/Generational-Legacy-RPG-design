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
| `data/art/scenery.json` | The battle scenery: a scene per kind of land, what some places add, the weather, the seasons and props |

`tests/test_game_art.gd` checks that the data is sound and that every creature, class and race has art, and
`tests/test_game_scenery.gd` that every place has scenery. `tools/art_sheet.gd` draws all of it on one sheet:

```bash
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/creatures.png
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/heroes.png what=heroes
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/places.png what=scenery
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/swamp.png what=scenery place=mirefen scale=2
```

The last one draws a place in every weather and then in every season.

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

## Scenery

A fight is drawn in front of the land it happens in: `ui/play/scenery_art.gd` paints the scene of the place in
the world's weather and season, behind everything in the battle arena. The battle screen veils it toward its
background (`veil`, thicker with high contrast: `veil_high_contrast`) and puts a dark plate under each name,
so the figures stand out.

A place takes its own scene from `places` (`"elderglade": {"scene": "fae"}`), else the scene of its first
biome in `data/world/world.json`, else the `fallback` scene. A place can add `layers` of its own: a town on
the skyline, a ship, sea cliffs. They go where the scene has `{"op": "place"}`, or last. Out of doors (a
scene without `"indoor": true`), the layers of the season (`seasons`) and then of the weather (`weather`)
follow. A layer can carry changes for a season, used in it: `"autumn": {"colors": [...]}`,
`"winter": {"kind": "dead"}`.

A scene is painted at `size` (384 x 120) and scaled up by whole pixels like the sprites. Each place is
painted with its own dice, seeded from the place, never the game's, so a place always looks the same. The
screen stretches it over the arena, cut to the arena's shape from its top (`SceneryArt.crop`), so a short
arena loses the near ground and never the sky.
`horizon` is where the sky meets the ground, as a fraction of the height.

Each layer is one `op` with its own settings. Colours run from lit to shaded, or from far to near.

| op | Draws | Settings |
|----|-------|----------|
| `sky` | Flat bands from the top to the horizon | `colors` top to bottom |
| `wall` | Courses of blocks: rock, masonry, a floor | `y` [from, to] of the height, `brick` [w, h], `colors`, `mortar`, `rough`, `grow` (each course taller), `edge` |
| `clouds` | Domes on a flat base | `count`, `y` [from, to] of the sky, `w` [min, max], `colors` [lit, shade] |
| `stars` | Points, some with rays | `count`, `y`, `bright`, `colors` |
| `orb` | A sun or moon with rings of glow | `x`, `y` (of the sky), `r`, `colors` [face, rim], `glow`, `glow_alpha` |
| `ridge` | Mountains (`"kind": "peaks"`) or hills (`"round"`) on the horizon | `base` (rows below the horizon), `height` [min, max], `spacing` [min, max], `x` [from, to], `colors` [lit, shade], `snow`, `snow_at` |
| `trees` | A line of trees | `kind` pine, broad or dead, `base`, `size` [min, max], `gap` [min, max] or `count`, `drop`, `x`, `colors` [lit, mid, shade], `trunk` |
| `columns` | Columns at fractions of the width | `x` [...], `base`, `height`, `w`, `broken` (a chance), `colors` [lit, mid, shade] |
| `spikes` | Stalactites (`"from": "top"`) or spikes standing on the horizon | `count`, `len`, `w`, `base`, `colors` [lit, shade] |
| `islands` | Rocks floating in the sky | `count`, `w`, `y`, `colors` [top, lit, shade] |
| `town` | Towers, houses with lit windows, a wall | `x` [from, to], `base`, `height`, `towers`, `tower_height`, `wall`, `wall_height`, `colors` [wall lit, wall shade, roof lit, roof shade], `lights` |
| `ground` | Bands from the horizon down, nearer ones taller | `colors` far to near |
| `water` | A band of water with glints and foam | `y` [from, to] of the ground, `colors`, `glint`, `glints`, `foam` |
| `road` | A winding track with ruts | `y`, `wave`, `colors` [dirt, ruts, verge] |
| `pools` | Pools lying on the ground | `count`, `w`, `y`, `colors` [water, rim] |
| `cracks` | Glowing cracks: lava, the rift | `count`, `len`, `y`, `colors` [hot, bright] |
| `details` | Grass `tuft`, `flower`, `pebble`, `dash` or `rock`, nearer ones larger | `kind`, `count`, `y`, `x`, `colors` [lit, shade, accent] |
| `scatter` | Props from `props`, the far ones first | `props` [ids], `count`, `y`, `x`, `recolor` {key: colour} |
| `prop` | One prop | `id`, `x`, `base`, `flip`, `recolor` |
| `band` | A see-through band: mist, smoke, a glow | `y` [from, to] of the height, `color`, `alpha` |
| `tint` | The sky, the ground or all of it moved toward a colour | `region`, `color`, `amount` |
| `particles` | Rain, snow, embers, motes | `shape` dot, plus, streak or flake, `count`, `y` (of the height), `len`, `alpha`, `colors` |

Props are grids in the sprites' format, without the reserved keys, drawn standing on their bottom row.
`SceneryArt.validate()` reports unknown layers, props and colours.
