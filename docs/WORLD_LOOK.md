# The world look (what is built)

This is step 5 of the art direction, "the world": how the open-world map's ground, water and light are drawn. It is rendering only. The world's rules and every seeded result are as they were (`GameWorldGen`, `GameRelief`), and no die is drawn. (`docs/ART_DIRECTION.md`, on the art-direction branch, holds the brief; fold a pointer to this page into its step 5 when that branch is merged.)

## Built

- **Ground with texture.** Each ground kind has 2 to 4 variants (specks, tufts, pebbles, cracks, flakes) drawn in code from `data/art/ground.json` and chosen by a hash of the tile, so a tile always looks the same and its neighbours differ. They live in a second atlas source of the tile set; the flat atlas is unchanged.
- **Soft edges.** Where two land kinds meet, the kind of higher rank bleeds a ragged, fading band onto the other; the ranks and the band's shape are in the data. A per-chunk `edges` layer holds them, chosen by the neighbours (`GroundArt.edge_for`), and takes the relief's brightness step.
- **Water that moves.** Four frames of drifting glints per water variant, played as a tile animation. Reduced motion holds the first frame. A light foam edge runs along every shore.
- **Soft shadows.** Under trees, rocks, ruins and tents: a low-alpha ellipse in a per-chunk layer, falling south-east (the sun is in the north-west). Town buildings cast a layered soft shadow in the overlay.
- **Light.** The overlay lays the colour of the light from `GameDay.look(d)` over the map: the tint as the light fails, a warm sun by day. Hearths, anvils, forges, camp fires and lit windows glow at night on an additive layer, flickering a little (still with reduced motion). A fog greys the view; rain and snow fall from `look["precip"]` (off with reduced motion); a soft vignette darkens the edge, a little more at night.

## Where

`ui/play/ground_art.gd` (variants, edges, atlases, textures, the data check), `ui/play/world_look.gd` (what is drawn over the map), `ui/play/tile_view.gd` (the layers), `ui/play/sandbox_screen.gd` (the `glow_layer` and `sky_layer` and the calls), `data/art/ground.json`, `data/art/light.json`, `tests/test_game_world_look.gd`.

## Not built

Foam that moves; shadows that spill into the next tile or follow the time of day; wind in the trees; seasonal ground (snow on plains in winter); lit windows placed from each building's own art; weather sound.
