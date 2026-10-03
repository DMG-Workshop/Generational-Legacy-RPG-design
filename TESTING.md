# Testing Phase 1: Lineage Core

## Running Tests

### Install GutTest (Godot Unit Testing)

```bash
cd /home/user/GenerationalLegacyRPG
godot --headless --script res://addons/gut/gut_cmdline.gd
```

Or add GutTest as a Godot plugin:
1. Create `addons/gut/` directory
2. Download GutTest from https://github.com/bitwes/Gut
3. Copy files into `addons/gut/`

### Run Specific Tests

```bash
# Lineage system tests
godot --headless -s res://addons/gut/gut_cmdline.gd -gtest=res://tests/test_lineage.gd

# Integration tests (generation loop)
godot --headless -s res://addons/gut/gut_cmdline.gd -gtest=res://tests/test_integration_generation_loop.gd

# All tests
godot --headless -s res://addons/gut/gut_cmdline.gd -gtest=res://tests/
```

## Test Coverage

### `test_lineage.gd`
- ✓ Founder creation
- ✓ Heir production from parents
- ✓ Fate Value rolling
- ✓ 999-generation simulation
- ✓ Trait inheritance probability
- ✓ Fate tier perception (Charmed → Ill-Starred)

### `test_integration_generation_loop.gd`
- ✓ 5-generation family saga
- ✓ Fate milestone distribution across 100 generations
- ✓ Heir archetype assignment after failure
- ✓ Trait conflict handling
- ✓ Fate modifiers from traits

## What Each Test Validates

### Lineage System
- Family tree structure (parent/child relationships)
- Trait inheritance with probability
- Trait mutations (15% chance)
- Generation tracking (Gen 0 → 999)
- Heir creation from two parents

### Fate System
- Fate Value rolled at birth (1-30%)
- Milestone probability calculated (1 - (1 - P)^(1/5))
- Severity assignment based on Fate
- Heir archetype assignment (6 types)
- Perception tiers (Charmed/Steady/Uncertain/Ill-Starred)

### Data-Driven Content
- 30 traits loaded from JSON (bloodline, acquired, curses, blessings)
- Trait effects and mutations defined
- Trait conflicts detected
- Dormancy tracked (future feature)

## Test Design Philosophy

**Deterministic:** Every test uses a seeded RNG (e.g., `Lineage.new(42)`). Same seed = same results. This lets us validate the 999-generation saga is reproducible.

**Isolated:** Each system (Lineage, Fate) is tested independently before integration tests run them together.

**Scale:** `test_simulate_999_generations` actually produces 999 heirs to catch scaling bugs early.

## Next Phase Triggers

After Phase 1 tests pass:
1. Add Battle prototype (combat engine)
2. Add World system (tile world, digging, building)
3. Add Generation loop (transition between heirs)
4. Integrate all three

## Debugging

### Print Heir Info
```gdscript
var heir = lineage.get_current_heir()
print(heir)  # Uses Heir.to_string()
print("Traits: ", heir.traits)
print("Fate: %.2f (%s)" % [heir.fate_value, heir.fate_tier])
```

### Print Family Tree
```gdscript
for gen in range(lineage.generation_count()):
	var heir = lineage.get_heir(gen)
	print("Gen %d: %s (traits: %s)" % [gen, heir.name, heir.traits])
```

### Verify Trait Loading
```gdscript
print("Trait catalog size: ", lineage.trait_catalog.size())
for trait_id in lineage.trait_catalog.keys():
	print("  - ", trait_id)
```

## Known Limitations (Phase 1)

- Dormant traits not yet stored (will skip generations)
- No legacy echoes or reputation system (Phase 2)
- No battle mechanics (Phase 2)
- No world/building (Phase 3)
- No NPC parents or generation transition UI (Phase 4)

## Success Criteria for Phase 1

✓ Lineage tests pass (family tree, inheritance, Fate)
✓ Integration test runs 999 generations without crash
✓ Traits load correctly from JSON (30 traits × 4 categories)
✓ Failure distribution matches expected ~1-2 critical failures per 10 generations
✓ Seeded RNG produces identical saga when run twice with same seed
