# Reach across walls

Design for what a blow, a shot, a spell or a creature's attention may cross, and what stops it. Status: the **melee contact rule is built and tested**
(`GameWalls.line_clear`, `GameSandbox.reaches_heir`, `tests/test_game_reach.gd`); the rest is specified here with the places it would be read.

## Why

A town's wall ring (radius 34, `data/world/walls.json`) blocks *walking*, but `GameSandbox._contact()` used only the straight distance between a
creature in `chase` mode and the heir (`contact_range` 1.5 tiles, `contact_join` for the pack). A creature pressed against the outside of a wall could
start a fight with a heir standing a tile away on the inside. The same hole applies to any solid thing: a town building, a built wall, a shut gate.

## Terms

- **Reach line**: the straight segment from the attacker's point to the target's point, in tiles (the same points `heir_point()` and a creature's
  `x`, `z` already use).
- **Stops a reach**: a tile that cuts a reach line. Today: a town wall or tower (`GameWalls.SOLID`), a gate's passage while the gates are shut
  (`GameWalls.shut_now`), a town building's body (`GameTown.blocks`), and (not built) a family-built wall piece.
- **Does not stop a reach**: open ground, water, a ford, a tree or outcrop (they block *walking*, not a strike: a creature can bite past a trunk), a
  fence-height or low feature (none exists yet), an open gate's passage, a door that is open.
- The tile the line *starts* in is never tested: a creature standing in a gate's passage, or the heir in it, is not walled off from the open side.

## 1. Rules

### Melee reach (built)

A creature can **start a fight** (`GameSandbox._contact`) only if it is in `chase`, within `contact_range` (or, for others joining, `contact_join`)
**and** the reach line to the heir is clear. `GameSandbox.reaches_heir(agent, range)` is the one test; `GameWalls.line_clear(a, b, gates_shut, step)`
does the sampling. The line is sampled every `reach_step` tiles (`sandbox.json`, 0.25): a wall one tile thick (the thinnest there is) is never
stepped over, because 0.25 is under half a tile.

A creature outside the wall therefore stays in the world, in `chase`, and does not start a fight. It is not removed or hurt.

### Ranged attacks (specified; not built in the open world)

Open-world fights are the turn-based battle screen (`GameBattle`), reached by contact, so there is no projectile to fly in the world today. The rule for when
there is (a creature with `range` in its tags shooting at the heir, a companion's bow in `GameCompanions._guard`):

1. A ranged attacker needs `line_clear(attacker, target)` at the moment it fires; a clear line out to its `range` in tiles is its reach.
2. A shot that is blocked is lost, not redirected: the shooter keeps its target and moves (see AI below) to find a clear line.
3. A flier does not change the line's rule (a wall stops an arrow whatever flies it) but **does** ignore the *walking* block, so it may come over a wall
   and stand on the inside; the line then holds between it and the heir as for any creature.
4. A slit or a bar that is not solid to a line (see Edge cases) may let a *ranged* attack through and stop a *melee* one.

Where the battle screen itself starts from a distance (a hunt chosen on the life screen) nothing changes: that is not an open-world position.

### Area and emanation effects (specified)

An area effect spreads from an **origin** (a creature, a spell's cast point `GameBattle.cast_point`, a trap) over tiles in a shape the spell data already
names (`burst`, `cone`, `line`, `all`, `party` in `data/spells/spells.json` `target.shape`). In the open world (not built):

1. A tile is hit only if the straight line from the origin to that tile is clear (`line_clear`); a wall casts a **shadow** behind it. A `burst` is
   a disc clipped by the shadow, a `cone` is the cone clipped by it, a `line` stops at the first stopper.
2. `all` and `party` shapes are not geometric: they are not clipped (they are the battle's own sets), but they can only start from an origin that is
   itself in reach of the target set's area (a spell cannot be aimed across a wall at a fight on the other side).
3. An **emanation** that is not an attack (a shrine's glow, a lantern's light, `GameDungeonArt.darkness`) is a *light* rule and is separate: light
   already stops at walls in dungeons through `propdefs`; it is not changed here.
4. Damage over time from an area (fire, acid rain) is applied to a tile each tick only while the tile is inside the clipped shape; a wall built or
   broken during the effect changes the shape on the next tick.

Inside the **battle screen** nothing is clipped: a fight is a closed arena with no terrain, as now.

### AI target and pathing checks (specified; the creature step is not changed yet)

`GameBehaviour.step_all` decides `chase` from `sight` (a distance, with `sight_night`/`sight_day`) and steers by the router when there is one
(`GamePath.router`), which already refuses walls and shut gates. Today a creature **sees through** a wall (distance only). Rules:

1. **Seeing** needs a clear line as well as distance: a creature whose line to the target is stopped does not *acquire* a new target by sight. It
   keeps an existing one for `lose_sight_mult` times its sight, as now, so a chase round a corner is not dropped at once.
2. **Smell and hearing** (`alert_radius`, pack calls, a heard fight) are not line-of-sight rules and ignore walls; they raise a `chase`, not a strike.
3. A creature in `chase` whose strike line is blocked and whose *path* is long (the wall's far side is more than `chase_detour_mult` times the
   straight distance away by `GamePath.find`) **loses interest** and returns (`return` mode): it does not stand against the wall for ever.
   (`chase_detour_mult` is a new `behaviour.json` default; suggested 4.)
4. Packs flank by bearing (`flank_spread`); a flank point that is inside the wall (`GameWalls.blocks`) is moved to the nearest walkable tile.
5. The router is used for the *heir's side* too: a town guard (`GameVillagers.guards`) is not a creature and does not change.

## 2. Edge cases

| Case | Rule | Built |
|---|---|---|
| **Thin wall** | The thinnest wall is one tile; sampling every 0.25 tile cannot skip it. A line that only *grazes* a corner point is treated by tile (floor of the point), so grazing the very edge of a solid tile counts as through. | yes |
| **Diagonal wall / corner clipping** | A line that steps diagonally from tile A to tile B is blocked when **both** orthogonal neighbours of that step are solid (the two walls meet at a corner); one solid neighbour does not block it. This matches the walker's rule (`GamePath` never cuts a corner). | yes |
| **Chequer of walls** | Every step is a corner step: no gap. | yes |
| **Wall tile at the target or attacker** | The start tile is never tested (a creature in a gate's passage). A *target* tile that is solid blocks (the heir cannot stand in one, so this only guards bad input). | yes |
| **Gate, open** | Passage tiles are not solid: a reach passes. Guards stand inside (`posts`). | yes |
| **Gate, shut (night)** | The passage stops a reach as a wall does (`shut_now`). The portcullis or leaf is drawn across it (`WallArt` `leaf`). | yes |
| **Gate with a portcullis / bars (distinct from solid)** | Not in the data today (the arch's portcullis is only a drawing above the passage). If bars are added: a `bars` tile **stops walking and melee, not a ranged line or a spell**; the validator wants every `bars` tile's `stops` list (`walk`, `melee`, `ranged`, `area`) in `walls.json`. Suggested for a shut gate with a grille: `stops: [walk, melee]`. | no |
| **Window / arrow slit** | A `slit` is a wall tile with `stops: [walk, melee, area]` and **not** `ranged`: a defender behind it can be shot at and can shoot, and nothing walks or bites through. Towers already draw slits (`WallArt` `slit`); they are decoration today. | no |
| **Doors (family-built)** | A closed door stops a reach; a door is open while someone stands in it. `GameBuild` pieces: `wall` and `roof` stop a reach, `door` does while shut, `floor`/`road` do not. | no |
| **Knockback** | A knockback or pull moves a body along a line and **stops at the first tile that stops walking** (the wall face); it never moves a body *through* a wall, and the body that hits it takes no extra damage unless the effect says so. A pull toward the caster ends in front of the first stopper. | no |
| **Pull / teleport / blink** | A blink needs the destination in reach *and* a clear line (it is not a walk). A teleport to a named place ignores the line (it is not a reach). | no |
| **Flying across a wall** | A flier may enter the wall's tile column (it is not walk-blocked) but cannot *end* a move on a solid tile; a strike from above a wall still needs the line from its point to the target to be clear of *other* solid tiles. | no |
| **Upstairs / indoors** | `_contact` already returns early upstairs and indoors; nothing reaches across floors. Dungeon contact (`_dungeon_contact`) is inside one interior whose walls are `prop`/wall cells; it is not yet using `line_clear` (follow-up). | no |
| **Companions** | `GameCompanions._guard` engages by distance to the threat; it should use the same `line_clear` so a guard does not duel a creature through a wall. | no |
| **Gates shut with the heir in the passage** | The heir can always step *out of* a shut passage (only the target tile is tested). Nothing is trapped. | yes |

## 3. Alignment with the repo

- **Logic in `core/game/`, UI only draws.** `GameWalls.line_clear` is pure (no dice, nothing saved). `reach_step` is in `data/world/sandbox.json`.
- **No dice.** The rule draws nothing, so seeded fights, golden digests and the autopilot are untouched (the autopilot never calls `_contact`).
- **Same blocks as walking.** It reads `GameWalls`, `GameTown` and the shut-gate state that `GamePath.world_ground` reads, so a wall and a gate mean the
  same to a step and to a blow. The gates' night state is `GameWalls.shut_now(d)`.
- **Corner rule matches pathing.** `GamePath` never cuts a corner; `line_clear` refuses to squeeze through the same corner.
- **Data-driven stoppers.** When `bars` and `slit` are added they are entries with a `stops` list in `walls.json` (and the validator), not code.

## Affected files

Built: `core/game/game_walls.gd` (`stops_reach`, `line_clear`, `_stop_at`, `_stops`), `core/game/game_sandbox.gd` (`reaches_heir`, `_contact`),
`data/world/sandbox.json` (`reach_step`), `tests/test_game_reach.gd`, `CLAUDE.md` (Contact entry).

To change for the specified rules: `core/game/game_behaviour.gd` (`_see` / chase acquisition, `chase_detour_mult`, flank point fix),
`data/creatures/behaviour.json`, `core/game/game_sandbox.gd` (`_dungeon_contact`, `_guard_fights`), `core/game/game_companions.gd` (`_guard`),
`data/world/walls.json` and `GameWalls.validate` (`stops` lists), `ui/play/wall_art.gd` (a bars drawing), a knockback/pull effect in `GameBattle` only
when the battle has a map (it has none).

## Follow-up edge cases (not decided)

- A family-built wall *piece* (`GameBuild`) stops a reach, but only `GamePath` knows built pieces as solid; `line_clear` needs a `built` argument (the
  `world_ground` overlay) to read them. The Contact path would pass `d.built`.
- Two creatures on opposite sides of a wall that each see the other's fight: noise (alert) crosses the wall, a strike does not. Whether a *heard* fight
  should pull a chase round the long way is the `chase_detour_mult` question above.
- Elevation: a creature on a slope above a wall (the ring is on flat ground inside 34 tiles, but outside it is not) could in principle strike over
  a wall's top. The wall is drawn three tiles tall; the rule treats it as unbounded height. A height rule (`wall_tiles` against the height difference) is
  possible and not needed yet.
- Draw: a creature stuck against a wall in `chase` should look stuck; a short "hammering at the wall" cue (cosmetic) is a UI nicety.
