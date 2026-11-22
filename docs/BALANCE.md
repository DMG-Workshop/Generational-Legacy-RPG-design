# Balance

The roadmap's target is that **battle deaths stay between 3% and 7%** of lives: the share of heirs whose life ends "slain in battle", when the autopilot (`GameBot`) plays. The harness measures it.

## Running the harness

```bash
godot --headless --path . -s res://tools/balance_harness.gd
```

With no arguments it plays seeds 1 to 12: each seed is a batch that plays one 10-generation dynasty for each of the eight starting races (about 80 lives), and each batch runs in its own Godot process, one per processor. On four processors the default run takes about four minutes; on one it takes about fifteen.

| Argument | Meaning |
|---|---|
| `seeds=1-12` | The base seeds, as a range or a list (`1,5,9`) |
| `gens=10` | Generations played per dynasty |
| `races=human,elf` | Only these starting races |
| `jobs=4` | Batches at the same time |
| `check` | Exit with 1 when the overall share is outside the band |

It prints one line per seed, the overall figure, a table by the race of the heir (the hybrid races appear through marriages), and a verdict.

The harness writes nothing but small temporary files, which it removes, and the game's `user://` saves are not used, so it can run next to other work.

## Reading the result

- **Use the overall figure and its range, not single seeds.** A batch is only about 80 lives, and one death is 1.25 points. Seeds 1 to 12 below range from 1.2% to 7.5% with nothing wrong.
- The range printed is the 95% range for the overall figure. When it reaches past 3% or 7%, the run cannot tell a near miss from noise: add seeds (`seeds=1-40`).
- The per-race rows rest on 100 to 130 lives each (the hybrids on fewer than 20), so they are good to a few points at best.
- **Compare before and after on the same arguments.** The numbers follow from the seeds the tool plays. They cannot be compared with figures quoted from other tools, such as the harness this one replaces.
- Playing is deterministic: the same arguments on the same code give the same figures.

## Checking a change

A change that alters the autopilot or auto-battle results is a balance change (CLAUDE.md). Run the harness on the commit before the change and on the change, with the same arguments, and put both overall figures and their ranges in the pull request.

## Baseline

Seeds 1 to 40, 10 generations (`seeds=1-40`, about 10 minutes on four processors), at the commit that added the harness:

| | Lives | Slain | Share | 95% range |
|---|---|---|---|---|
| Overall | 3,200 | 110 | 3.4% | 2.9-4.1% |

The overall share is inside the band. It is also a good picture of why a single seed means little: with the true rate near 3.4%, **19 of the 40 seeds fell under 3% and 3 went over 7%**, and the slain count per seed ran from 0 to 8 (0% to 10%). The old note that some seeds landed near 2.5% was this noise.

By race of the heir:

| Race | Lives | Slain | Share |
|---|---|---|---|
| beastkin | 378 | 1 | 0.3% |
| orc | 376 | 0 | 0.0% |
| human | 313 | 11 | 3.5% |
| dragonborn | 359 | 12 | 3.3% |
| halfling | 426 | 21 | 4.9% |
| dwarf | 403 | 19 | 4.7% |
| gnome | 364 | 19 | 5.2% |
| elf | 337 | 17 | 5.0% |
| half_dragon | 85 | 3 | 3.5% |
| half_elf | 72 | 7 | 9.7% |
| half_orc | 87 | 0 | 0.0% |

- The long-lived races (dwarf, elf, gnome, halfling) sit at 4.7-5.2%, a little above humans and inside the band. Nothing here says a long life stacks up too many chances to die.
- The short-lived ones stand out the other way: **the autopilot almost never loses an orc or a beastkin in battle** (1 in 754 lives). They die of old age at a mean level of 31-35, before the autopilot's Hard hunt rules (level 40 and up) let it take the risky fights. That is the autopilot's caution more than the game's difficulty, but it is where the numbers differ most.
- The hybrids appear only through marriages, so their rows rest on 70 to 90 lives and are good to several points at best.

## Long runs and budgets

The harness above answers "are battle deaths in the band?". The **long run** answers "is anything getting heavier?": `tools/long_run_check.gd` plays whole dynasties for many generations with the autopilot and measures, per dynasty, the generations reached, the size of the final save, how long it takes to load, how long a generation takes to play and the journal's size, against `data/game/budgets.json`.

```bash
godot --headless --path . -s res://tools/long_run_check.gd -- seeds=1-2 gens=60 races=human,elf check
```

`check` makes it exit 1 when something is over budget. The size and "the line carries on" limits are exact; the time limits are generous because a shared machine is slow. A save grows about 0.3 KB per generation (older heirs fold into the Ages), so the size budget is a base plus an allowance per generation reached. A generation takes about a second to play, so 60 generations is a minute per dynasty. `.github/workflows/long-runs.yml` runs it every night, one race per job, and from the Actions tab by hand with other seeds or generations. When a night fails, `tools/replay.gd -- record` on the same seed and a replay play it again exactly.

## Subclasses

The twenty callings (`data/subclasses/subclasses.json`) were measured with the harness: the autopilot plays whole dynasties founded in one calling, and the result is compared with the same seeds, races and generations with no calling.

```bash
godot --headless --path . -s res://tools/balance_harness.gd -- seeds=1-12 subclass=armorer keep   # one calling
godot --headless --path . -s res://tools/balance_harness.gd -- seeds=1-12 subclass=all keep      # the sweep, one line each
```

`subclass=<id>` founds every dynasty in that calling (`GameDynasty.new_game`'s subclass argument); the game's own 50% inheritance then passes it on, so only about 2 lives in 10 would carry it. **`keep` founds every heir in it**, so all lives carry the calling at founded strength: the effect on a life, undiluted, and the number to read. `long_run_check.gd` takes `subclass=<id,id|all>` too. The harness also prints gold at death, kills, wins and the generations reached per dynasty (`Balance.detail`). `tests/test_game_balance_tool.gd` covers the argument, a founded batch, `keep`, and a long run in a calling.

**What the autopilot can use.** It fights (`attack_mult`, `spell_mult`, `defense_mult`), settles hunts (`hunt_gold_mult`, `hunt_xp_mult`), drinks potions (`potion_mult`), trains (`train_mult`), shops for gear (`buy_mult`), sells finds when the pack is full (`sell_mult`, `carry_mult`), searches the dead (`gather_mult`, `essence_mult`, `drop_mult`, `rarity_mult`) and meets sickness (`disease_mult`). It **cannot** use: creatures (`find_mult`, `keep_mult`, `fertility_mult`, `mutation_mult`, `value_mult`), the forge (`forge_fee_mult`, `craft_quality_mult`, `salvage_mult`, `brew_yield_mult`), mining (`ore_mult`, `dig_mult`, `cave_mult`), building and the farm (`build_cost_mult`, `farm_mult`, `raid_mult`), foraging, companions' hauls, odd jobs (`work_mult`) and fleeing (`flee_mult`: the bot never flees). The Breeder, Artificer and Delver have no perk the bot reaches, and the sweep shows it: their runs are **identical to the baseline** (same 26 deaths, same gold, to the digit). For these perks the arithmetic is covered by `tests/test_game_subclass_perks.gd`, and `tests/test_game_subclass_roster.gd` (`test_strength_bands`) holds every founded perk within 0.4x-2.0x, and any perk that acts in the heir's fights, training or hunts within 25% of 1. Their effect on a *played* life (creature income, ore, building) is **not measured**; only their cost against their strength could be judged on paper.

### Method and noise

Seeds 1-12, 8 starting races, 10 generations (960 lives per row), `keep`, the same seeds for every row, before any change. A calling with a fight perk changes the dice order of every later fight, so a row is a fresh draw of 960 lives, not the baseline plus a small shift: the **baseline-to-row difference has a standard deviation of about 1 point** in battle deaths (a row's 95% range is about 1.8 points wide each side). Differences under about 1.5 points on one run are not evidence. The check used was to re-run the callings that stood out on 24 new seeds (13-36, 1,920 lives each).

### Table (seeds 1-12, `keep`, before the change)

| Calling | Slain (of 960) | vs none (pts) | Mean level | Mean age | Gold at death | Kills |
|---|---|---|---|---|---|---|
| none | 26 (2.7%) | +0.0 | 59 | 190 | 4,775 | 122.5 |
| breeder | 26 (2.7%) | +0.0 | 59 | 190 | 4,775 | 122.5 |
| runescribe | 24 (2.5%) | -0.2 | 58 | 187 | 4,743 | 120.9 |
| armorer | 37 (3.9%) | +1.2 | 57 | 183 | 4,834 | 118.5 |
| bladewright | 28 (2.9%) | +0.2 | 57 | 182 | 4,643 | 117.7 |
| enchanter | 23 (2.4%) | -0.3 | 58 | 185 | 4,740 | 119.4 |
| alchemist | 21 (2.2%) | -0.5 | 59 | 189 | 4,853 | 122.8 |
| artificer | 26 (2.7%) | +0.0 | 59 | 190 | 4,775 | 122.5 |
| gemwright | 27 (2.8%) | +0.1 | 59 | 191 | 4,775 | 122.9 |
| hidewright | 30 (3.1%) | +0.4 | 57 | 181 | 4,255 | 116.8 |
| trapsmith | 31 (3.2%) | +0.5 | 59 | 192 | 5,333 | 123.2 |
| spiritbinder | 34 (3.5%) | +0.8 | 59 | 174 | 4,842 | 113.6 |
| wildcaller | 40 (4.2%) | +1.5 | 58 | 181 | 4,530 | 119.1 |
| feastwright | 31 (3.2%) | +0.5 | 59 | 190 | 4,799 | 123.3 |
| wayfinder | 30 (3.1%) | +0.4 | 58 | 186 | 4,915 | 119.8 |
| delver | 26 (2.7%) | +0.0 | 59 | 190 | 4,775 | 122.5 |
| stonewright | 36 (3.8%) | +1.1 | 58 | 189 | 4,539 | 122.2 |
| greenwarden | 42 (4.4%) | +1.7 | 59 | 187 | 4,898 | 121.5 |
| steadholder | 32 (3.3%) | +0.6 | 58 | 189 | 4,543 | 121.7 |
| caravaneer | 33 (3.4%) | +0.7 | 59 | 192 | 5,023 | 125.1 |
| venomwright | 21 (2.2%) | -0.5 | 57 | 178 | 4,387 | 115.4 |

Every row is inside, or just under, the band's range (the plain house itself is 2.7% on these seeds and 3.3% on seeds 13-36, 3.1% on all 36). No calling makes the autopilot's lives noticeably easier or harder in level (57-59), kills (114-125) or gold (4.3k-5.3k; the hidewright at -11% and trapsmith at +12% were not re-run, so read them as unconfirmed).

### The five that stood out, on 24 more seeds (13-36)

| Calling | Seeds 1-12 | Seeds 13-36 | All 36 seeds (2,880 lives) |
|---|---|---|---|
| none | 26 (2.7%) | 63 (3.3%) | 89 (3.1%) |
| armorer | 37 (3.9%) | 51 (2.7%) | 88 (3.1%) |
| greenwarden | 42 (4.4%) | 44 (2.3%) | 86 (3.0%) |
| stonewright | 36 (3.8%) | 52 (2.7%) | 88 (3.1%) |
| wildcaller | 40 (4.2%) | 91 (4.7%) | 131 (4.5%) |

Armorer, greenwarden and stonewright changed sign: noise (and the armorer's +8% defense could only lower deaths). **The wildcaller held** (+1.5 and +1.4 points, 131 against 89 deaths, about 2.8 standard errors). Its only perk the autopilot reaches is `train_mult` (1.1, so 1.15 founded): training gives levels sooner, which opens the autopilot's Hard hunts (level 40 and up, `bot_hard_hunt`) earlier, and those are where it dies. Mean level rose to 60.

### The change

| Calling | Perk | Before | After |
|---|---|---|---|
| wildcaller | `train_mult` | 1.10 | 1.04 |

Re-measured on all 36 seeds, `keep`: **wildcaller 90 slain of 2,880 (3.1%, range 2.5-3.8%)**, level 57, gold 4,433, kills 116: the baseline's 89 (3.1%). Nothing else was changed: the other nineteen are within noise on battle deaths, level, kills and gold, and their perks are modest (the strongest perk the autopilot reaches is a founded +15% spell power or +12% hunt XP). The prices (`price_mult`) were left alone: the autopilot never buys a calling, and a calling's cost is 300 gold times the generation scale, small against the 4-5k gold a life ends with.

### Long runs

`tools/long_run_check.gd -- seeds=1 gens=40 races=human subclass=all` (20 dynasties of 41 generations, one per calling) is within every budget: saves are 23.1-24.1 KB (budget 40.5 KB), loading is 2-3 ms, a generation plays in 0.5-1.5 s, and every journal stops at 300 lines. Only the battle-death share is flagged (2.1% of 800 lives from one seed, below the band), as the plain house is on the same seed; that is the seed, not a calling.

### What a retune should do

Judge a calling by arithmetic first (the perks above the autopilot cannot reach have no harness signal) and by `subclass=<id> keep` on at least 36 seeds when it touches the fights, training, hunts or potions; one 12-seed run cannot tell a 1.5-point change from noise.
