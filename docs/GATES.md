# Waygates: the arches of the Old Roads

Design note for the gates (`core/game/game_gates.gd`, `data/world/gates.json`, `ui/play/gate_art.gd`, `data/art/gates.json`,
`ui/play/gate_panel.gd`; tests `tests/test_game_gates.gd`, `test_game_gate_art.gd`, `test_game_gate_panel.gd`).

## The lore

Before the roads were paved there were the Old Roads: lines of standing arches that a traveller could step through at one and come out at
another, a day's walk or a world away. Each arch is a ring of old stone with a **rune cut for every slot** along it, each rune inlaid with
**silver**. The runes say what the arch does, and the silver carries the light. Lit, an arch answers the others of its road.

That was long ago. Stone wears. Runes fade, and silver is worth more to a thief than a road is to a carter, so the arches are mostly
broken now: a rune worn to a scratch, a groove with its silver prised out. A few are tended and still shine (Hearthmere's, Ironford's,
Kingshold's); the greatest, at Highcrag, is nearly dust. The door to each of the other worlds is also an arch, and also ruined, and its lock is
a rune in that world's own hand. To use a gate a family must **re-craft** it: learn the runes, bring silver and gold, and cut them again
where they fell out, and then keep watch over it.

## The alphabet

Fourteen runes: seven of the road and seven of the realms (`runes` in gates.json).

| Rune | Wears | Cost | What the old books say |
|------|-------|------|------------------------|
| road | 0.025 | 1.0 | The Old Road remembers the foot that walks it. |
| door | 0.030 | 1.0 | A door is a promise that there is another side. |
| bind | 0.020 | 1.1 | What the arch joins, the bind holds. |
| light | 0.040 | 0.9 | The lamp-rune: silver drinks the day and gives it back as the arch wakes. |
| return | 0.030 | 1.1 | No traveller is let through who has no road home. |
| ward | 0.020 | 1.2 | Keeps the arch from taking more than it was given. |
| deep | 0.020 | 1.3 | Reaches under the world, where the far doors are kept. |
| bough, barrow, wing, ember, cog, dream, void | 0.035 | 1.5 | The key of one realm each: the Verdant Court, the Hollow Below, the Dragon Isles, the Elemental Planes, the Clockwork Expanse, the Dreaming, the Void. |

"Wears" is steps a year (see below), "cost" a multiplier on the repair's gold. Common runes are found more easily (`weight` 3 or 2) than
the realm runes (1).

## The gates

Seventeen, each a landmark at a fixed place. `anchor` in gates.json is an offset from a place's anchor (or a realm's `realm_gates` tile); the
gate is moved to the nearest **dry, flat (height within 1), clear ground, off every wall, building, node, dungeon mouth and the cleared ground
before a town gate**, with an open tile in front (`placed`, a pure function of the seed and the land, no dice). The wilds keep off the ground
round an arch (`GameGates.claims`, asked by `GameWildsSites._spot_ok`).

* **Four at the towns**, just outside the wall and beside the road, not on it: Hearthmere, Ironford, Kingshold, Brinehaven. A **road smith**
  keeps a stall at each and sells silver (40 gold, scaled by generation, ten at a time at most).
* **Six in the wilds beside ruins** (fallen stones at their feet): Greenvale, Whisperwood, Elderglade, Frostreach, Highcrag, Stormcoast.
* **Seven doors to the realms**, one for each gateable realm, each with that realm's own rune among its slots.

Gates have 4 to 7 rune slots by size (`sizes`: small 4, medium 5, grand 6, great 7). They belong to **networks** (`networks`): the King's
Road, the Wild Road (Ironford and Highcrag are on both, so they are the crossings) and, for a realm's door, the way to that realm.

## The state of a gate (a pure function)

`GameGates.state(d, id)` is `{slots: [{rune, state}], lit, mode, condition, failed, worn}`, and it is worked out, not stored, from the seed,
the gate, the slot and the **world year** (`d.world.year`, whole years):

1. **At year 0** a gate has its `whole` slots (the ones with the lowest keyed rolls) whole; every other slot is dealt `worn` (20%), `broken`
   (35%) or `stripped` (45%) by `start_split`. Hearthmere's, Ironford's and Kingshold's arches start with every slot whole (lit); Brinehaven's
   has one; the realm doors have none.
2. **Wear.** A slot loses a step a year at its rune's `wear` times a keyed jitter of up to 40% either way: whole to worn at one step, to
   broken at two. The lamp-rune goes in about 25 years, the ward in about 50, and a broken slot is broken for good.
3. **Theft.** In a year a gate is robbed with probability `theft_chance` (3%) times its `exposure` (0.5 in the wilds, 1.2 to 1.5 at the
   towns). A keyed die says which slot loses its silver: it is **stripped**, whatever its wear. Over 600 years the gates are robbed about
   as often as the data says (the test checks it).
4. **Repair.** A slot repaired in year Y is whole from Y and begins to wear again then; thefts before Y no longer count against it.
5. **Guard.** A companion posted at a gate (the `guard` order from GameCompanions) keeps thieves off: no theft in a year after they were
   posted strips the slot while they serve, nor in the years they served before they were relieved or died. The family's last look
   (`seen`, kept by `GameGates.tend`, which the sandbox calls as the heir walks) bounds the years a guard who has stopped serving is
   credited with. Wear is not stopped by a guard; it takes the silver, not the stone.

The mode: **lit** when every slot is whole, **flickering** when none is broken or stripped and some are worn (`dark_at` 1: a single broken or
stripped slot darkens the gate), **dark** otherwise. `condition` is whole slots plus half the worn ones over the slot count.

An untended lit gate goes through flickering to dark in a generation or two of play; a family that watches a gate has to re-cut a
worn rune now and then (cheap), a family that does not will find its silver gone.

## Repair

At the stones, `GameGates.inscribe(d, id, slot)` needs: the **heir within reach** (`reach` 2.5 tiles), the **rune known**, **silver**
and **gold**. It spends them, records `fixed["gate:slot"] = year` and, if the gate is a realm's door and is now lit, calls
`GameRealms.open_gate`, which sets the existing `gate_<realm>` flag so creatures can be moved between the realms as before.

| State | Silver | Gold | (times size cost, rune cost, generation scale) |
|-------|--------|------|-----|
| worn | 1 | 12 | |
| broken | 2 | 35 | |
| stripped | 3 | 60 | |

Size cost: small 0.8, medium 1.0, grand 1.3, great 1.6. At the first generation a medium gate's `light` rune costs about 11 gold, 1 silver
to touch up when worn and about 31 gold, 2 silver when broken, so the family's 300 starting gold mends a small ruin; a great gate is
a project of several generations.

The Runescribe pays half the gold (`rune_fee_mult` 0.5) and only two of the three silver to relay a stripped slot (`rune_silver_mult`
0.67), and **knows every rune**.

### Learning the runes (three sources, all in data)

1. **Copy a legible rune.** Any whole or worn slot can be copied for free at the stones (`copy_rune`). At the start the home arches show
   most of the road runes, so a first visit teaches them.
2. **Old inscriptions.** Searching a ruin, standing stones, shrine, hermit or old battlefield may teach a rune the family lacks
   (`settings.lore`, a keyed die on the seed, the landmark and how often it was used; never the dynasty's dice). The realm runes are
   rarer than the road ones.
3. **The Runescribe subclass** knows them all.

Left for later: a scholar who sells rubbings, and rubbings in dungeon loot.

### Silver

`silver` is the existing precious material: mined (`mining.json`, depth 50 and under), from outcrops of hills, mountains and tundra from
generation 6, and now bought from the road smith at a town's gate.

## Stepping through

Use at an arch in the open world (the ground floor, not indoors, not in a fight) opens the **gate panel**: the world waits. It shows the
arch's slots as a row of rune pictures with their state, a repair list (cost and reason as text under each key), copy keys, the road smith,
the guard post, and, when the arch works, the gates it leads to with name, place and distance, and a **Step through** key.

`GameSandbox.step_through(gate, dest)`:

* The destination must be a working gate on a shared network (or the gate's own realm). A **flickering** arch (at either end) needs a
  **charge**: 1 silver, or any one essence. A lit pair is free.
* The trip takes `base_seconds` 3 plus `per_tile` 0.04 a tile, capped at 30 seconds, of **world-clock seconds** fed to `GameClock.feed`: the
  heir ages, wages are paid and the day moves exactly as they would walking. (The longest trip is half a year of the clock.) It draws no die
  of the dynasty's, unless the clock rolls a year over, as it would walking.
* The heir comes out on the open tile in front of the far gate, creatures near the old one are left behind, companions who follow stand
  beside them (guards, stayers and gatherers keep their posts), and `_arrive()` runs for a town place.

## The realms' arrival grounds (phase 2)

A lit realm gate leads to `realm/<id>`: a small walled clearing (19 by 13 tiles with a few pillars, the same on every seed) in the palette
of the realm's mark (`looks` in gates.json), entered on the return gate. It is an ordinary interior to the sandbox (`GameSandbox.space`,
`GameInterior.cells`), so walking, saving and the screens work as in a building, and Use on the return gate comes out in front of the
realm's gate. The return always works; it is the gate's far side, not the arch's state.

**Time** in the realm runs at the realm's `flow` (the Verdant Court 0.5, the Elemental Planes 1.5): the screen feeds `GameClock` that
share of the seconds (`GameSandbox.time_flow`), through `pass_time` as everywhere. This is the scoped version of "time flows at the
realm's rate": it speeds or slows the heir's own clock, not the open world's, which has only one.

**Wildlife** is a tested seam: `GameGates.arrival_creatures` lists a few creatures of the realm (from realms.json `of`) on keyed floor tiles.
The sandbox does not set them on the floor yet.

## Nothing here is the rules of a life

`GameGates` is asked by the sandbox, the gate panel, the maps and the wilds' use of a landmark, never by `pass_time`, hunts, `GameBot`
or the golden digests; `tests/test_game_gates.gd` greps the core for that. Only the family's doings are saved (`GameDynasty.gates`,
only once set; runes learned, slots repaired and the year, gates found, guards posted with the years they served).
