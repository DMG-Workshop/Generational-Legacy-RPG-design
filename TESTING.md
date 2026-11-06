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

Never run suites in parallel on one machine. They share the `user://` save files and fail when they overlap.

A suite can exit 0 and still have skipped checks: if a script error stops a test partway, Godot prints `SCRIPT ERROR` and the suite goes on to report `0 failures` with fewer checks. When you run suites by hand, look for that text, and compare the check count with the last run.

## Continuous integration

`.github/workflows/tests.yml` runs the game suites on every pull request and on every push to `main`. Each suite gets its own job, so a pull request shows which one broke, and the jobs run in parallel on separate machines, so the `user://` rule above doesn't apply to them. The list of suites is read from the `tests/` folder: a new `tests/test_game_*.gd` file is picked up with no change to the workflow.

Each job downloads Godot, checks its SHA-512, imports the project, and runs one suite. It fails if the suite exits non-zero **or** prints `SCRIPT ERROR`. A last job, **All game suites**, passes only when every suite did; it is the one to mark as a required check in the repository's branch protection settings.

The Godot download, checksum and project import are in `.github/actions/setup-godot/action.yml`, which the release workflow uses too. To move to a newer Godot, change the version and the hashes there. The hashes are in the `SHA512-SUMS.txt` file on that release at https://github.com/godotengine/godot-builds/releases.

## What each suite covers

| Suite | Covers |
|-------|--------|
| `test_game_aging.gd` | Companion ageing, old age, death and retirement, successors, saves and the autopilot |
| `test_game_art.gd` | The battle sprites: the art data is sound, every creature, class and race has art, race and class colours, whole-pixel scaling, and the battle screen drawing from sprites with the old blocks as fallback |
| `test_game_balance_tool.gd` | The balance harness's logic: seed lists, the 95% range, the verdict against the band, and a small reproducible autopilot batch |
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
| `test_game_tutorial.gd` | The first-heir tips' logic: the data is sound, each condition works, the tips come in order, nothing is saved |
| `test_game_house.gd` | The family house's rules: costs per level and the top, buying takes only gold, the Hall's party places, the Yard's training XP, an empty house changes nothing, saves and old saves |
| `test_game_sex.gd` | Sex in the dynasty: the founder's start choice, spouses always the opposite sex, children rolled both ways, old saves filled in |
| `test_game_saves.gd` | Save slots and backups without screens: slot files, atomic saving with its `.bak`, loading from the `.bak`, the slot summary, backup text out and back in, every way a pasted backup can be wrong |
| `test_game_saves_ui.gd` | Slots on the real screens: the title's slot list, begin and continue per slot, the ask before covering or erasing a house, Copy and Restore backup, the game menu's Copy backup |
| `test_game_tutorial_ui.gd` | The tips on the real screens: the strip follows play and marks buttons, Skip tips and the menu switch, the succession tip |
| `test_game_access.gd` | The accessibility options: the three settings, a damaged value reading as off, the colour and contrast variants, reduced motion, and the menu's Accessibility row |
| `test_game_adoption.gd` | Adoption: with no children, companions are offered as heirs; the one chosen leaves the company, and saves keep where they came from |
| `test_game_family_tree.gd` | The family tree: one entry per generation, folded heirs counted, damaged names dropped, and the chronicle's Family Tree tab |
| `test_game_house_ui.gd` | The House panel on the life screen: Build raises a track and takes the gold, and a row that cannot be built says why |
| `test_game_mates.gd` | Mates: opposite-sex candidates, looking at them changes no dice, the one chosen becomes the spouse, and the random spouse without a choice |
| `test_game_mates_ui.gd` | The mate picker on the life screen: Found family opens the candidates and a pick marries that one |
| `test_game_reactions.gd` | Standing covers: setting and cycling a cover, the health threshold, once a round, a fallen coverer, and an unused cover leaving the fight unchanged |
| `test_game_reaction_prompt.gd` | Reactions that ask first: the round stops on "Cover this ally?", an answer plays it on, letting it land is the old round exactly, and the battle screen's question |
| `test_game_stats.gd` | The dynasty statistics: heirs, causes of death, the greatest heir, gold per kept heir and per Age, folding, and the chronicle's Statistics tab |
| `test_round_determinism.gd` | Seeded battles around party rounds match the golden fixture (see below) |

Each suite's header comment says what it proves and gives its own run command.

## Determinism and the golden fixture

All randomness comes from the dynasty's seeded RNG, so the same seed with the same commands gives the same result. `tests/fixtures/round_baseline.json` records the battle digests from before party rounds were added. `test_round_determinism.gd` recomputes them and fails if anything changed.

Regenerate the fixture only from the commit before a deliberate behaviour change, with `tests/capture_round_baseline.gd`. Never regenerate it to make a failing test pass.

## Balance checks

Autopilot changes are balance changes. The balance harness is `tools/balance_harness.gd` (not a test suite, so CI does not run it): the autopilot plays many dynasties and it reports the share of heirs slain in battle, which should stay in the 3-7% band. Run it before and after a change with the same arguments and show both figures. How to run it and how to read it, including why single seeds are noisy, is in `docs/BALANCE.md`. Its logic (`tools/balance.gd`) is covered by `tests/test_game_balance_tool.gd`.

## Older prototype tests

The `tests/test_*.gd` files that don't start with `test_game_` test the older prototype code (`core/battle`, `core/lineage`, `world/`, `ui/screens` and others) that the game does not use. Many of them extend `GutTest`, and the GUT addon is not in this repo, so they don't run as they are. Don't treat them as a gate. Check them before relying on them.
