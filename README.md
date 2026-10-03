# Generational Legacy RPG

A 999-generation JRPG/CRPG hybrid where you play an entire family saga across 25,000 years of fantasy history. Every choice, trait, and failure ripples through your bloodline forever.

## Vision

Play one heir's full life, then continue as their child while your old character becomes an NPC parent. Traits, debts, heirlooms, reputation, and curses pass down and mutate. The world remembers what your ancestors did—factions reward or hunt you based on family history, NPCs judge you by your grandparents' choices, and geography itself changes as civilizations rise and fall.

## Features

- **999 Generations:** ~25,000 years in one playthrough
- **Trait Inheritance:** Bloodline powers mutate, dormant traits resurface, conflicts create friction
- **Fate & Failure:** Random failures shape heirs into Restorers, Rebels, Redeemers, or Successors
- **Legacy Echoes:** Every ancestral act becomes a story that affects descendants
- **Multiple Worlds:** Nine realms with time dilation, teleportation networks, and persistent estates
- **Layered Combat:** Final Fantasy side-view with class mechanics, skill trees, and ancestral arts
- **Dig & Build:** Terraria-style exploration with persistent structures that decay across generations
- **Data-Driven:** All content (traits, classes, jobs, creatures) in JSON; logic independent of rendering

## Getting Started

### Prerequisites

- Godot 4.x (free, open-source)
- GDScript (Python-like scripting language)

### Project Structure

```
/docs/GDD.md             Full game design (25,000 words)
/CLAUDE.md               Project guidance & architecture
/data/                   JSON trait/class/item definitions
/core/                   Game logic (no rendering)
  ├── lineage/           Family tree & inheritance
  ├── fate/              Failure system
  ├── memory/            Legacy echoes & reputation
  ├── battle/            Combat engine
  └── sim/               Age transitions & decay
/world/                  Tile world, digging, building
/ui/                     Rendering & menus
/tests/                  Unit tests
```

## Development Roadmap

**Phase 1: Lineage Core** (In progress)
- Family tree with trait inheritance and mutation
- Fate Value rolls and milestone checks
- Failure system with heir archetypes
- Text-only simulation of 999 generations for testing

**Phase 2: Battle Prototype**
- Side-view combat with front/back rows
- Two class families and basic keystones
- Skill trees and class advancement

**Phase 3: Tile World**
- One realm with dig/build mechanics
- Chunked save system
- Persistence across generations

**Phase 4+**
- Generation loop and NPC parents
- Legacy echoes and faction reputation
- Remaining classes, jobs, realms, and Ages
- Sieges and world decay (Strata system)

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
- 999 generations across 8 ages
- Combat with layered mechanics
- Nine worlds with time dilation
- High-magic setting with 9 peoples and 12 schools

## Contributing

This is a solo project scaffolding. Work through one roadmap phase at a time. Build and test each system before the next depends on it.

## License

MIT (to be added)

---

**Status:** Early development | **Started:** Oct 2026
