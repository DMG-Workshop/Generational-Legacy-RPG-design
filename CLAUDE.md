# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Godot 4.7 with GDScript. Commands assume `godot` is on the PATH.

- Import assets and scripts (once in a fresh checkout): `godot --headless --path . --import`
- Play the game: `godot --path .` (main scene `ui/main.tscn` loads `main.gd`, which starts `ui/play/game_app.gd`)
- Run one test suite: `godot --headless --path . -s res://tests/test_game_round.gd`
  - Exit code 0 means pass. A suite prints `N checks, M failures` (or `ALL PASS`) and exits 1 on any failure.
- Run every game suite, one after another:
  `for t in tests/test_game_*.gd tests/test_round_determinism.gd; do godot --headless --path . -s res://$t || echo "FAILED $t"; done`
- Never run suites in parallel. They share the `user://` save files and fail when they overlap.
- Debug Android APK: `godot --headless --path . --export-debug "Android" build/GenerationalLegacy-debug.apk` (the Android SDK and JDK are configured in Godot's editor settings). The iOS preset only exports on a Mac with Xcode.
- The balance harness (autopilot, 10 generations x 3 seeds, all races) is not committed to this repo. The balance targets are in `docs/ROADMAP.md`: battle deaths stay in the 3-7% band.

## Architecture

Only the text game is wired into the app. The older prototype code is described at the end of this section.

- **Logic and rendering are separate.** `core/game/` makes no UI calls. `ui/play/` screens read dynasty state and call its methods, and they never compute results. New rules go in `core/game/` with a test in `tests/`.
- **Content is data.** `GameData` (`core/game/game_data.gd`) loads every JSON file under `data/` once, through `load_all()`. The tunable settings are in `data/game/balance.json` (Hard hunt rules, death chance), `data/combat/rounds.json` (party rounds), `data/classes/classes.json` (class skills, auto-battle `style`, openers) and `data/ui/mobile.json` (touch and layout sizes). Don't hardcode numbers in code.
- **State lives in `GameDynasty`** (`core/game/game_dynasty.gd`): the heir, the party, the world, the current battle, `command_round` and `auto_party`. It saves through `to_dict()` and `from_dict()`. A new field must load from an old save, and needs a test for that.
- **Battles.** `GameBattle` owns the round: heir, allies, foes, events and log. Its `round_on` hold lets manual party rounds use the same methods, and it is inert when no party round is open. `GameTactics.auto_turn` picks actions for auto-battle, the autopilot and any party member on Auto. `GameRound` queues manual party commands, resolves them together and retargets members who have died.
- **Autopilot.** `GameBot` (`step`, `live_life`, `wants_hard_hunt`) plays without input for the tests and the "Auto" buttons. Changing when it or the battle draws a random number changes every seeded fight, and the determinism tests will catch that.
- **Determinism.** All randomness comes from the dynasty's seeded RNG. The same seed with the same commands gives the same result, including after a save and load between rounds. `tests/fixtures/round_baseline.json` is a golden file made by `tests/capture_round_baseline.gd`. Regenerate it only from the commit before a deliberate behaviour change, never to make a failing test pass.
- **Touch.** `ui/play/touch_hint.gd` gives long-press previews on phones (`TouchHint.on_hover`). `ui/play/ui_settings.gd` stores the text size, the touch layout and the autopilot cooldowns in `user://settings.cfg`, not in the save. Touch targets are at least `touch_target_px` tall.

**Older prototype, not used by the game:** `core/battle`, `core/lineage`, `core/fate`, `core/economy`, `core/crafting`, `core/equipment`, `core/legacy`, `core/simulation`, `core/generation`, `world/`, `ui/screens`, `ui/components`, `ui/animations`, and the `tests/test_*.gd` files that don't start with `test_game_`. Nothing in the playable game refers to them. Don't extend them unless asked, and check before treating their tests as a gate.

## Conventions

- Old saves must keep loading. Missing keys fall back to defaults, and corrupt values must not crash loading, so check the type (for example `typeof(v) == TYPE_BOOL`) before using a saved value.
- A change that alters autopilot or auto-battle results is a balance change. Say so in the PR and show the before and after numbers.
- Don't add new `.uid` files or commit anything under `.godot/`.
- Documentation: `docs/GDD.md` is the design, `docs/ROADMAP.md` lists what is done and what is next, and `docs/MOBILE.md` covers touch, text size and the Android and iOS export setup. `TESTING.md` describes how the game's headless suites run. The `GutTest` files among the older prototype tests need an addon that isn't in this repo.
