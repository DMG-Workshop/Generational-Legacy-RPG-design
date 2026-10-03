# Core Systems

These are the logic layers that drive all 999 generations. They have no rendering dependencies and are fully testable in isolation.

## Modules

### lineage/
Family tree, inheritance, trait mutations. Handles:
- Creating a new heir from two parents
- Trait inheritance with probability
- Trait mutations and dormancy
- Trait conflicts

**Key classes:**
- `Lineage` — family tree manager
- `Heir` — individual character with stats and traits
- `TraitData` — trait definition and expression

### fate/
Fate Value calculation and failure mechanics. Handles:
- Rolling Fate at birth
- Milestone checks throughout a life
- Failure severity tiers
- Transforming heirs into archetypes (Restorer, Rebel, etc.)

**Key classes:**
- `Fate` — Fate Value calculation
- `Failure` — failure severity and archetype assignment
- `FateTier` — perception omen (Charmed, Steady, Uncertain, Ill-Starred)

### memory/
Legacy echoes, reputation, and faction relationships. Handles:
- Creating legacy echoes from ancestral acts
- Reputation decay by generation distance
- Faction standing based on history
- Quest hooks generated from legacy

**Key classes:**
- `LegacyEcho` — a remembered ancestral act
- `Reputation` — faction standing for a bloodline
- `QuestHook` — automatically generated from echoes

### battle/
Layered combat engine (no rendering). Handles:
- Combat state (HP, MP, party, enemies, turn order)
- Class mechanics (stances, spell-weaving, oath meter, etc.)
- Keystones (special rules)
- Equipment and trait effects stacking
- Outcome calculation

**Key classes:**
- `Battle` — combat orchestrator
- `Combatant` — an individual fighter
- `Layer` — a combat modifier (class, job, trait, keystone, gear, era)

### sim/
Age transitions, world decay, and strata compression. Handles:
- Advancing to a new Age
- Decaying structures based on maintenance
- Burying old surfaces under new strata
- Preserving Ancient Vaults

**Key classes:**
- `AgeTransition` — advancing from one Age to the next
- `Strata` — a layer of the world from a specific Age
- `Decay` — calculating structure degradation

## Testing Strategy

Each system is tested with unit tests in `/tests/test_*.gd`. Integration tests verify that systems compose correctly.

**Critical test:** Simulate 999 generations with all systems active. Verify:
- Trait inheritance works at scale
- Fate failures are rare (1-2 critical failures per 10 gens on average)
- Legacy echoes compound correctly
- No crashes or data corruption

## Design Constraints

1. **No rendering:** These systems know nothing about screen, input, or graphics.
2. **Data-driven:** All content from JSON files in `/data/`
3. **Deterministic:** Same seed = same generation every time
4. **Composable:** Each system works independently and together

## Implementation Order

1. **Lineage** — build and test trait inheritance first
2. **Fate** — add failure mechanics
3. **Memory** — add legacy echoes and reputation
4. **Battle** — move to combat after the three above are solid
5. **Sim** — world simulation once the above prove stable
