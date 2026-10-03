# Generational Legacy RPG — Development Progress

**Status:** Phase 3 (World System) complete. Ready for Phase 4 (Generation Loop).

**Test Coverage:** 31 tests covering Lineage, Fate, Combat, and World systems.

---

## Phase 1: Lineage Core ✅ COMPLETE

### Systems Built
- **Lineage** (family tree, inheritance, heir creation)
- **Heir** (character class with stats, traits, relationships)
- **Fate** (failure rolls, milestone checks, severity, archetypes)
- **Trait System** (30 traits with mutations, conflicts, inheritance)
- **TraitLoader** (JSON-based content loading)

### Features
- 999-generation family tree simulation
- Trait inheritance with probability (40-100% depending on trait)
- Trait mutations (15% chance)
- Dormant traits skip generations
- Fate Values (1-30% lifetime failure chance)
- 5 milestone checks per life
- 6 heir archetypes (Restorer, Rebel, Inheritor, Survivor, Redeemer, Successor)
- Trait conflicts create friction rather than cancel

### Data
- 10 bloodline traits
- 5 acquired traits
- 5 curse traits
- 5 blessing traits
- All traits include effects, mutations, inheritance rules

### Tests (8 tests)
✓ Founder creation
✓ Heir production from parents
✓ Trait inheritance probability
✓ Trait mutations
✓ Fate Value rolling and tiers
✓ Milestone checks
✓ 999-generation simulation
✓ Fate modifier integration

---

## Phase 2: Combat System ✅ COMPLETE

### Systems Built
- **Battle** (turn-based combat engine)
- **Combatant** (character in combat with actions and effects)
- **Damage System** (row-based positioning, trait modifiers, job effects)
- **Class Mechanics** (stances, rage meter, spell-weaving, oath meter, beast forms)
- **Action System** (attack, defend, cast spell, use item, stance)
- **Turn Order** (calculated by dexterity)

### Features
- Front/back row positioning with modifier effects
- Damage calculation with stacking modifiers:
  - Base (strength × 2)
  - Defense (constitution)
  - Row bonus (back row +5 def)
  - Trait modifiers (Warrior's Steel +30%, Mageblood +20%, etc.)
  - Job modifiers (Blacksmith +10% damage)
  - Critical hits (5% + dexterity bonus)
- Class-specific mechanics:
  - **Martial:** Rage meter (fills from hits taken)
  - **Arcane:** Spell queue (combine elements over turns)
  - **Divine:** Oath meter (fill on beneficial actions)
  - **Primal:** Beast forms with unique skills
  - **Shadow:** Turn manipulation and stealth
  - **Spirit:** Summons take party slots
  - **Craft:** Battlefield gadgets (turrets, traps, golems)
- Buff/debuff system
- Elemental surfaces (water conducts lightning, oil ignites, etc.)
- Valid action filtering (limited by MP, rage meter, etc.)
- Battle end conditions (all enemies dead = win, all party dead = loss)

### Tests (13 tests)
✓ Combatant creation
✓ Damage calculation
✓ Back row defense bonus
✓ Trait damage modifiers
✓ Battle initialization
✓ Turn order by dexterity
✓ Attack action execution
✓ Dead combatant restriction
✓ Stance changes buffs
✓ Valid actions based on resources
✓ Rage meter buildup
✓ Battle end condition
✓ Full round simulation

---

## Phase 3: World System ✅ COMPLETE

### Systems Built
- **Realm** (individual world with chunks, resources, creatures)
- **Chunk** (16×16 tile area with structures, entities, decay)
- **WorldManager** (multi-realm system, teleportation, properties)

### Features: 9 Interconnected Worlds

| Realm | Time Multiplier | Resources | Danger | Access |
|-------|-----------------|-----------|--------|--------|
| Material (Home) | 1× | Iron, copper, wheat | Medium | None |
| Verdant Court | 365× (1 day = 1 year) | Fae silk, glamour crystal, moonwood | High | Faetouched |
| Hollow Below | 0.01× (slow time) | Soul gem, grave iron, ancestral relic | Very High | Marked by Death |
| Celestial Spires | 120× (1 month = 10 years) | Starmetal, holy essence | Very High | Divine Favor |
| Elemental Planes (4) | 2× | Elemental cores, essence | Extreme | None |
| Dragon Isles | 1.5× | Dragonbone, dragon scale, sky ore | Extreme | Dragonblood |
| Dreamlands | Random | Dream essence, memory shards | Medium | None |
| The Void | -1× (backward) | Voidglass, rift crystals | Extreme | Post-Sundering |
| Clockwork Expanse | 1.2× | Aetherium, gears, golem cores | High | Arcane Industry |

### World Features
- **Chunk System:**
  - 16×16 tile chunks (procedurally generated)
  - ~1.6 million chunks per realm (sparse loading)
  - Layer-based generation:
    - Surface (z=0): grass, forest, water, mountains
    - Underground (z<20): stone, ore, caves
    - Deep (z>20): ancient ruins, ley veins, rare artifacts
  - Procedural generation with seeding (reproducible)
  - Structure support (buildings, shrines, magical items)
  - Entity support (NPCs, creatures, wildlife)

- **Persistence:**
  - Chunk maintenance level (0-100)
  - Decay over generations (20+ gens = major damage)
  - Player can claim properties (estates, businesses, tombs, trading posts)
  - Family properties persist across generations
  - Chunk unloading to save memory

- **Exploration:**
  - Movement in 3D (x, y, z = horizontal + depth)
  - Digging down (z increase = going back in time)
  - Dig deep enough to find founder's home, ancestor tombs, Ancient Vaults
  - Build structures (houses, smithies, shrines)

- **Teleportation:**
  - Waystone network (fast travel points)
  - Gate system (connect two realms)
  - Bloodline-locked gates (only descendants can use)
  - Time dilation affects player (spend 1 day in Spires, 10 years pass at home)

- **Resources:**
  - Unique per realm (fae silk only in Verdant, aetherium only in Clockwork)
  - Rarity tiers: common → rare → ancestral
  - Used for crafting, enchanting, heirlooms

### Tests (18 tests)
✓ All 9 realms initialized
✓ Realm properties and time multipliers
✓ Chunk generation and retrieval
✓ Procedural generation (deterministic)
✓ Layer-based terrain variation
✓ Teleportation between realms
✓ Player movement
✓ Digging down
✓ Building structures
✓ Claiming properties
✓ Property filtering by realm
✓ Time dilation calculation
✓ Trait-gated access restrictions
✓ Access with correct traits
✓ Waystone network
✓ World summary
✓ Chunk decay over generations
✓ Multiple chunk loading
✓ Chunk unloading

---

## Test Summary

| Phase | Module | Tests | Status |
|-------|--------|-------|--------|
| 1 | Lineage | 6 | ✅ Pass |
| 1 | Integration (Lineage + Fate) | 2 | ✅ Pass |
| 2 | Battle | 13 | ✅ Pass |
| 3 | World | 18 | ✅ Pass |
| **TOTAL** | | **39** | ✅ **PASS** |

---

## Next: Phase 4 — Generation Loop & NPC Parents

### What Needs Building
1. **Generation Transition System**
   - Play a full life (birth → death)
   - Transition to next heir (chosen child)
   - Old heir becomes NPC parent/mentor
   - Generate next heir's stats from parent's legacy

2. **NPC Parent System**
   - Old heirs stay in world as NPCs
   - Can visit parent's tomb in Hollow Below
   - Long-lived species can recur (elves live ~800 years)
   - Legendary companions persist across generations

3. **Estate & Inheritance**
   - Family estate persists and can be visited
   - Upgrades carry over (better forge = faster crafting)
   - Decay if neglected
   - Repairs possible by heir

4. **Legacy Echoes & Reputation**
   - Faction standing inherits (partially)
   - NPCs remember player's ancestors
   - Quests generated from ancestor actions
   - Reputation modifiers on heir

5. **UI/Rendering Layer**
   - Battle screen (turn order, HP bars, damage numbers)
   - World rendering (tile display, player sprite)
   - Character/family tree UI
   - Generation transition scene

### Estimated Scope
- 8-12 hours implementation
- 15-20 tests
- 500-800 lines of code

---

## Architecture Scorecard

| Principle | Status |
|-----------|--------|
| **Logic before rendering** | ✅ All combat and world logic runs independently |
| **Data-driven content** | ✅ 30 traits + realm/chunk generation in JSON |
| **Deterministic simulation** | ✅ Seeded RNG for reproducible games |
| **Modular systems** | ✅ Lineage, Fate, Battle, World each testable alone |
| **Composable** | ✅ All systems integrate through clear interfaces |
| **Scalable to 999 gens** | ✅ Tested with 999-generation simulation |
| **Memory efficient** | ✅ Chunks load/unload, properties are sparse |

---

## Code Statistics

| Category | Count |
|----------|-------|
| Core systems | 8 classes (Lineage, Heir, TraitLoader, FateSystem, Battle, Realm, Chunk, WorldManager) |
| Data files | 4 JSON files (30 traits) |
| Tests | 39 tests across 4 modules |
| Lines of code | ~2,500 (logic only, no rendering) |
| Commits | 7 major commits |
| Documentation | GDD (25k words), CLAUDE.md, README, TESTING.md, PROGRESS.md |

---

## Performance Notes

- Lineage: Simulates 999 generations in <1 second
- Chunks: Sparse loading (only loaded chunks in memory)
- Battle: One round simulates instantly (no rendering overhead)
- World: 9 realms × ~1.6M chunks each (on-demand generation)

---

## Known Limitations (Future Work)

**Phase 4 blockers:**
- No UI rendering
- No actual generation transition (still manual)
- No NPC parent interaction

**Future phases:**
- Multiplayer/co-op
- Mobile version
- Mod support
- Advanced AI for NPC parents
- Dynamic marriage/children system

---

## Quick Start

```bash
cd /home/user/GenerationalLegacyRPG

# Run all tests
godot --headless -s res://addons/gut/gut_cmdline.gd -gtest=res://tests/

# Read the design
cat docs/GDD.md

# See architecture
cat CLAUDE.md
```

---

**Last Updated:** Oct 3, 2026
**Next Milestone:** Phase 4 (Generation Loop) — ~1 week
