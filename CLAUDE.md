# Generational Legacy RPG — Project Guidance

## Engine & Architecture

**Engine:** Godot 4 with GDScript

**Core Design Principle:** Logic is completely separated from rendering. All game systems (battle, traits, Fate, reputation, world simulation) run independently of the graphics layer. This allows the 2D side-view prototype to be reskinned as isometric 3D later without changing core logic.

**Content Delivery:** All content (traits, classes, jobs, keystones, monsters, items, realms) lives in JSON data files. Code reads data; no hardcoding. This makes balancing, testing, and expansion straightforward.

**Determinism:** Random number generation is seeded, so entire generations and Age transitions are reproducible and testable in isolation.

## Repository Structure

```
/docs/GDD.md                  Full game design document
/data/traits/*.json           Trait definitions (bloodline, acquired, curses, blessings)
/data/classes/*.json          Classes and advanced/era-locked variants
/data/jobs/*.json             Jobs and their combat/building effects
/data/keystones/*.json        Skill tree keystones that rewrite combat rules
/data/items/*.json            Weapons, armor, runes, heirlooms
/data/creatures/*.json        Monster and NPC creature definitions
/data/realms/*.json           World realms, time multipliers, resources
/core/lineage/                Family tree, inheritance, trait mutation
/core/fate/                   Fate Value calculation, milestone checks, failure severity
/core/memory/                 Legacy echoes, reputation, faction standing
/core/battle/                 Layered combat engine (no rendering calls)
/core/sim/                    Age transitions, decay, strata compression
/world/                       Tile world, chunks, building, digging persistence
/ui/                          Rendering: battle screen, menus, family tree view
/tests/                       Unit tests for core systems (use GDScript test framework)
```

## Current Roadmap Phase

**Phase 1: Lineage Core** (Current focus)

Build and test the family tree, trait inheritance, mutation, and Fate system in isolation. Start with text-only simulation: 999 generations passing through the system, checking that:
- Traits pass down with correct probabilities
- Mutations occur and chain correctly
- Dormant traits can skip generations
- Fate Values are rolled and milestone checks work
- Failures transform properly and affect the next heir
- Legacy echoes compound correctly

This is the foundation. Every system depends on it working correctly.

## Key Files to Know

- `docs/GDD.md` — The complete design, 25,000 words of mechanics and lore
- Core tests will live in `/tests/test_lineage.gd`, `/tests/test_fate.gd`, etc.

## Next Steps

1. Set up Godot 4 project structure
2. Create trait definition schema and load system
3. Build family tree and inheritance engine
4. Implement Fate roll system
5. Write integration test: simulate 999 generations, verify all systems
6. Only after Phase 1 is green: move to battle prototype

## Design Principles (Preserve These)

1. **Logic before rendering.** Battle system computes results; UI renders them.
2. **No hardcoding.** Everything data-driven.
3. **Fail visibly.** Test early, test often. A generation system with bugs now is catastrophic at Gen 500.
4. **Modular.** Lineage doesn't know about battles. Battles don't know about the world. Each system is testable alone.
5. **Persistent and reactive.** The world remembers everything. Choices ripple forward 999 generations.
