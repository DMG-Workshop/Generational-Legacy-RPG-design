# Generational Legacy RPG

A 999,999-generation JRPG/CRPG hybrid where you play an entire family saga across millions of years of fantasy history. Every choice, trait, and failure ripples through your bloodline forever.

## Vision

Play one heir's full life, then continue as their child while your old character becomes an NPC parent. Traits, debts, heirlooms, reputation, and curses pass down and mutate. The world remembers what your ancestors did—factions reward or hunt you based on family history, NPCs judge you by your grandparents' choices, and geography itself changes as civilizations rise and fall.

## Features

- **999,999 Generations:** the world turns through Ages of 1,100 generations, each stronger than the last; legends rise again with every Age, and the saga ends with the heir of generation 999,999
- **Trait Inheritance:** Bloodline powers mutate, dormant traits resurface, conflicts create friction
- **Fate & Failure:** Random failures shape heirs into Restorers, Rebels, Redeemers, or Successors
- **Legacy Echoes:** Every ancestral act becomes a story that affects descendants
- **Multiple Worlds:** Nine realms with time dilation, teleportation networks, and persistent estates
- **Layered Combat:** Final Fantasy side-view with class mechanics, skill trees, and ancestral arts
- **Spells and Areas:** foes stand in front and back rows; bursts, cones, lines and field-wide spells strike every foe they reach, casters learn a spellbook as they level, and burns, poisons, stuns, wards and haste tick turn by turn
- **Feats:** martial techniques bought with feat points earned at level milestones and readied in a few slots, changed only in a town or right after a rest: cleaves, charges, stuns and rallies that cost no MP but wait out a cooldown, and tricks of the ground such as a rockslide in the mountains or caltrops that keep biting
- **Auto-battle:** a switch beside Hunt (and in every battle) that lets hunts fight themselves turn by turn with the autopilot's choices, until the player takes over
- **Dig & Build:** Terraria-style exploration with persistent structures that decay across generations
- **Data-Driven:** All content (traits, classes, jobs, creatures) in JSON; logic independent of rendering

## Getting Started

### Prerequisites

- Godot 4.x (free, open-source)
- GDScript (Python-like scripting language)

### Project Structure

```
/docs/GDD.md             Full game design
/docs/ROADMAP.md         What is done and what is next
/docs/MOBILE.md          Touch, text size and Android/iOS export
/CLAUDE.md               Project guidance & architecture
/data/                   JSON content: classes, combat, game balance, ui, ...
/core/game/              Game logic (no rendering)
/ui/play/                Screens for the playable game
/tests/                  Headless test suites (see TESTING.md)
```

The older prototype folders (`core/battle`, `core/lineage`, `world/`, `ui/screens` and others) are not used by the game. See CLAUDE.md.

## Play the Test Game

A self-contained playable slice (lineage, fate, echoes, heirlooms, turn-based battles, save/load).

1. Open the project in Godot 4.x once (so it registers the script classes), then press **F5**.
   Or from a terminal: `godot --path .`
2. Found a dynasty (class + bloodline + optional seed), then each ~2-year action: hunt, train, work, rest, found a family.
3. When an heir dies, choose which child carries the legacy. Traits pass on, go dormant, mutate and conflict; failures at Fate milestones shape the next heir.

Code: `core/game/` (logic, no rendering), `ui/play/` (screens), data in `data/classes`, `data/creatures`, `data/game`, `data/traits`, `data/spells`, `data/feats` and `data/combat` (statuses, elements, formations and packs).

Tests (headless): each `tests/test_game_*.gd`, e.g. `godot --headless --path . -s res://tests/test_game_generations.gd`, which also plays a house through to the end of generation 999,999. See TESTING.md for how to run them all and what each covers.

## Development Roadmap

The text game's queue is done: feats, battle diseases, a whole-game bug hunt, skill trees, mobile Android and iOS support (apart from testing on a real device), and party-command battles. What is left, and the sandbox that follows the text game, are in `docs/ROADMAP.md`.

## Design Principles

1. **Logic First:** Battle, traits, reputation, and simulation run independently of rendering
2. **Data Driven:** No hardcoding; all content in JSON
3. **Deterministic:** Seeded RNG for reproducible generations
4. **Modular:** Each system is testable in isolation
5. **Persistence:** The world never forgets

## Documentation

Read `docs/GDD.md` for the complete design. It covers:
- Trait system with mutations and conflicts
- Fate and failure mechanics
- Generations and Ages (the playable game runs 999,999 generations, in Ages of 1,100)
- Combat with layered mechanics
- Nine worlds with time dilation
- High-magic setting with 9 peoples and 12 schools

## Contributing

This is a solo project scaffolding. Work through one roadmap phase at a time. Build and test each system before the next depends on it.

## License

MIT (to be added)

---

**Status:** Early development | **Started:** Oct 2026
