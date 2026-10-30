# Testing the text game

The playable game is tested with headless Godot suites. No test addon is needed.

## Running tests

Commands assume `godot` is on the PATH. Import once in a fresh checkout first:

```bash
godot --headless --path . --import
```

Run one suite:

```bash
godot --headless --path . -s res://tests/test_game_round.gd
```

A suite prints `N checks, M failures` (or `ALL PASS`) and exits with code 0 on success, 1 on any failure.

Run every game suite, one after another:

```bash
for t in tests/test_game_*.gd tests/test_round_determinism.gd; do godot --headless --path . -s res://$t || echo "FAILED $t"; done
```

Never run suites in parallel. They share the `user://` save files and fail when they overlap.

## What each suite covers

| Suite | Covers |
|-------|--------|
| `test_game_aging.gd` | Companion ageing, old age, death and retirement, successors, saves and the autopilot |
| `test_game_bot.gd` | The autopilot's Hard hunt choice and the `bot_hard_hunt` rules in `balance.json` |
| `test_game_combat.gd` | Battlefield geometry, the ability pipeline and spellbook, statuses, elements, packs, spell costs and saves |
| `test_game_disease.gd` | Diseases: catching, worsening, cures, contagion, the black market and saves |
| `test_game_events.gd` | Events with skill checks: check math, gating, every outcome and event fights |
| `test_game_feats.gd` | Feats by class, gates, companions, MAG and STR scaling, and the autopilot's use of them |
| `test_game_generations.gd` | The long count: Ages, content gates, scaling, bounded saves and the end of the saga at generation 999,999 |
| `test_game_integration.gd` | Shops, gear, quests, events and companions together, including old-save fixtures |
| `test_game_items.gd` | Shops, equipment and the temple; every item reaches the player somehow |
| `test_game_mobile.gd` | Phones and tablets: hold-for-details, no hover previews from a finger, tooltips in the shipped UI |
| `test_game_party.gd` | Companions: hire, dismiss, upkeep, level sync, rest, succession, battles with allies and saves |
| `test_game_party_ui.gd` | The party command screen: a solo hunt is unchanged, and with companions each member is asked in turn |
| `test_game_plague.gd` | The battle side of sickness: carriers, toxins, plague vials, sick companions and determinism |
| `test_game_quests.gd` | Notice-board quests: content, rules, rewards, saves and the board |
| `test_game_round.gd` | Party command rounds: queueing, back, repeat last, retargeting, flee, reserved items and saves |
| `test_game_skills.gd` | Class skills by level and class style, unlock gates, once-a-battle skills and the journal |
| `test_game_trees.gd` | Skill trees: data validation, skill points, prerequisites, node effects, keystones and refunds |
| `test_round_determinism.gd` | Seeded battles around party rounds match the golden fixture (see below) |

Each suite's header comment says what it proves and gives its own run command.

## Determinism and the golden fixture

All randomness comes from the dynasty's seeded RNG, so the same seed with the same commands gives the same result. `tests/fixtures/round_baseline.json` records the battle digests from before party rounds were added. `test_round_determinism.gd` recomputes them and fails if anything changed.

Regenerate the fixture only from the commit before a deliberate behaviour change, with `tests/capture_round_baseline.gd`. Never regenerate it to make a failing test pass.

## Balance checks

Autopilot changes are balance changes. The balance harness (autopilot over 10 generations and 3 seeds, all races) is not committed to this repo. Battle deaths should stay in the 3-7% band in `docs/ROADMAP.md`. Show the before and after numbers when a change affects them.

## Older prototype tests

The `tests/test_*.gd` files that don't start with `test_game_` test the older prototype code (`core/battle`, `core/lineage`, `world/`, `ui/screens` and others) that the game does not use. Many of them extend `GutTest`, and the GUT addon is not in this repo, so they don't run as they are. Don't treat them as a gate. Check them before relying on them.
