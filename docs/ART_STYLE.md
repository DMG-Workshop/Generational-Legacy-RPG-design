# Art style

How new art is made so it matches the art there is: the palette, the outline, the light, the sizes and the
facing. `docs/ART.md` says how art is stored and drawn; this says how it should look. The numbers below are in
`data/art/style.json`, and `SpriteArt.style_problems()` holds every class figure and creature to the ones a
machine can check (run by `tests/test_game_art_style.gd`, `tools/check_data.gd` and the art sheet). The rest is
for review, with the art sheet beside the change:

```bash
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/creatures.png
godot --headless --path . -s res://tools/art_sheet.gd -- out=/tmp/heroes.png what=heroes
```

The numbers were measured on the art as it stands (29 creatures, 5 of them bosses, and 19 class figures), so a
sprite that follows them sits among them: outlines were on 93 to 100% of edges, there were no stray pixels, and
the most colours in one sprite was 13. **Checked** means a test fails when it is broken; **Review** means it is
guidance, judged by eye.

## At a glance

| Rule | Value | |
|------|-------|---|
| Outline | 1 pixel in `#1b1626`, on at least 90% of the silhouette's edge | Checked |
| Stray pixels | none: every pixel touches another | Checked |
| Colours | 12 aimed for, 14 at most, counting the outline | Checked |
| Class figure | exactly 24 x 40, facing right, standing on the bottom row, 1 pixel clear at the left and top | Checked |
| Creature | at most 40 x 40, facing left, 1 pixel clear at the left, top and right, feet within 3 rows of the bottom | Checked |
| Boss | at most 64 x 64 (the biggest so far is 56 x 56), the same margins as a creature | Checked |
| Light | from the top left | Review |
| Shading | 2 or 3 shades of a material | Review |
| Dithering, anti-aliasing | none | Review |
| Reads at 3x | the silhouette is clear at 3x scale on `#14121c` | Review |

## Palette

Colours come in families. Pick from the family, not a new colour.

**Fixed colours**

| Colour | Use |
|--------|-----|
| `#1b1626` | The outline of every sprite, and the darkest shade of the scenery. |
| `#14121c` | The game's background. A sprite must read against it. |

**Skin and hair** come from the race (`data/art/races.json`), never from the figure: a figure uses the reserved
keys `S s H h` and the race fills them. Each has a lit and a shaded tone, one step apart:

| Race | Skin | Shade | Hair | Shade |
|------|------|-------|------|-------|
| human | `#e8b98f` | `#c48d68` | `#5a3a24` | `#3e2718` |
| elf | `#f3d6bb` | `#cfa98b` | `#ede2a6` | `#bfae6e` |
| dwarf | `#e6a688` | `#bb7660` | `#b86a35` | `#7d4222` |
| orc | `#7fab58` | `#567d3a` | `#3a3238` | `#241e24` |
| halfling | `#e9b27f` | `#c08455` | `#9a6331` | `#6b4120` |
| gnome | `#f5c6aa` | `#d4927e` | `#e49ad8` | `#a95f9f` |
| dragonborn | `#d8653f` | `#a8442b` | `#cf5f3c` | `#a8442b` |
| beastkin | `#c99a63` | `#9b6d3f` | `#8a5a33` | `#5e3c20` |
| half-elf, half-orc, half-dragon | between their parents | | | |

**Shirts** (`data/art/shirts.json`), sixteen mid-tone colours; the figure's `C` key takes the colour and `c` a
shade 32% darker: crimson `#b8403a`, rust `#b8653a`, ochre `#c49a3c`, moss `#6e8a3c`, forest `#3f7a4a`, teal
`#2f8a84`, sky `#4a86c0`, navy `#3a4f8a`, violet `#7048a0`, plum `#8a3a6e`, rose `#c06a88`, sand `#c8b088`,
linen `#d8d2c4`, slate `#5f6a78`, charcoal `#3e3a44`, umber `#7a5236`. A new shirt is a mid-tone: not near
black or white, so the outline and the face stay readable on it.

**Elements** (`data/combat/elements.json`) are the accent colours of magic and of creatures that wield it. A
creature of an element carries it in its eyes, markings or glow, never over its whole body:

| Element | Colour | Looks like |
|---------|--------|------------|
| fire | `#ff7a3a` | orange and yellow |
| frost | `#8fd3ff` | icy blue |
| lightning | `#f2e65a` | yellow sparks |
| earth | `#c49a6c` | stone browns |
| nature | `#8fd14f` | greens |
| holy | `#ffe9a0` | pale gold |
| shadow | `#a07fd0` | purple, with glowing eyes |

**A creature's main colour** is its `color` in `data/creatures/creatures.json`, the colour players knew from the
blocks before there was art.

**Metals, woods and leathers** are spread in ramps in `data/art/gear.json` (light to dark). Use a ramp for gear,
and the class's own palette keys listed in the gear note, so gear can be recoloured.

## Outline

Every sprite has a 1-pixel outline in `#1b1626` all round its silhouette, and only the outline touches the
clear background. Inner lines (between an arm and a body) may use the darkest shade of the material instead,
so the sprite is not a grid of black. At least 90% of the edge must be the outline colour; the rest may be a
glow or a highlight breaking the line, as on a flame or an eye.

## Light and shading

Light comes from the top left. The lit side of a form (its top and left) gets the lightest shade, the right
and bottom the darkest. Use two or three shades of a material, not five: it keeps the sprites clean at the size
they are drawn. Highlights are one or two pixels, usually on the top left edge. No dithering (alternating
pixels to fake a blend) and no anti-aliasing (in-between colours on a curve).

## Sizes and the ground

- A **class figure** is 24 x 40. Rows 0-3 are headroom for hats. Every class keeps the same face pixels (skin,
  eye and nose at x 10-18, y 9-16), so the race layers line up on all of them.
- A **creature** is on a canvas of 32 or 40 pixels wide and at most 40 high; a **boss** at most 64 x 64.
  The canvases in use are 32 x 20, 32 x 28, 32 x 32, 32 x 36, 32 x 40, 40 x 32, 40 x 36 and 40 x 40, and
  56 x 56 for the five bosses.
- Everything stands on the **bottom row** of its canvas: a figure's feet touch row 39, a ground creature's
  row `h - 1`. A flying or floating creature (a wraith, a shade) may hang up to three rows above it.
- Leave **one clear pixel** at the left and top (and the right for creatures). A class figure's weapon may
  reach its right edge.

## Facing

Heroes and companions face right; creatures face left, toward them. The battle screen turns a sprite to face
the other side where it needs to (`FigurePose`), so never draw a mirrored copy.

## Readability

Look at every sprite at 3x scale on `#14121c` before sending it. The silhouette should say what it is at a
glance (a wolf is long and low, a golem wide, a wraith tall and ragged), and the eyes, if it has them, should
be the brightest pixels in the sprite. If two creatures of a kind share a silhouette, change the shape, not
only the colour: colour-blind players see the shape.

## Adding art

1. Draw it as a grid in the right file in `data/art/`, to the rules above.
2. Run `tests/test_game_art_style.gd` (or `tools/check_data.gd`). It names every rule broken, by sprite.
3. Open the art sheet, look at it at 3x, and put the sheet in the pull request.
4. If a rule truly has to bend for one sprite, change the number in `data/art/style.json` for everyone and say
   why in the pull request, rather than making an exception.
