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

## Perks the autopilot cannot use (measurement plan)

Twelve of the twenty callings have most of their power in places `GameBot` never visits (list under *What the autopilot can use*, above). The sweep cannot see them, so
"all twenty are within noise" says nothing about the Delver's ore, the Steadholder's flock or the Stonewright's walls. This section defines how to measure them. **Status: the profile bots are built (`GameProfile`, `profile=<id>` on the harness) and run once on the plain house, with first numbers below;
the per-calling comparison is only partly run.** Nothing here changes a seeded life: with no profile the autopilot plays exactly as before (`tests/test_game_profiles.gd` checks that).

### Terms (the same as above)

- **Plain house**: no calling. **Calling run**: `subclass=<id> keep`. **Founded strength**: `founder_scale` (1.5x on the perk's distance from 1).
- **Value in gold** (`GE`): everything a perk produces priced in gold with the numbers the game already has, so perks of different kinds can be compared:
  materials at `GameShops.unit_price(material)` (`material_unit` 6 gold times the material's `price_mult`), made pieces at `GameItems.sell_price`, creatures at their `GameRanch.sell`
  value, farm yield as paid gold, saved fees and costs as the gold not spent, raids prevented as `plain_chance` times the expected loss, hp saved as `potion_price` per heal share.
- **Effort** (`E`): the number of *player actions* a profile spends per generation (a dig, a forage, a craft, a build, an order). It is counted by the bot, not guessed, and is the price a
  human pays in attention. A perk that needs 400 actions for +50 GE is not the same as one that needs 4.
- **Risk** (`R`): extra expected battle death share per life while pursuing the profile (a delver goes deeper, a forager walks further), measured in points of battle deaths against the plain house on the
  same profile.

### Profile bots (built)

A **profile** is a small policy layered on `GameBot.live_life` that adds the actions a perk needs, and **only those**, through the same core calls the screens use (no new rules, so what it measures is
what a player gets). Each is run once for the plain house and once for each calling that has a perk it exercises. The set is in `core/game/game_profile.gd` and runs through `godot --headless --path . -s res://tools/balance_harness.gd -- seeds=1-12 profile=<id> [subclass=<id> keep]`. The harness prints, besides the usual figures, `gain` (gold-equivalent net-worth gain per life, `GameProfile.net_worth`), `effort` (player actions per life) and `GE per action`. The policies are first guesses (how often it acts, what it buys); change them in `GameProfile.hook`.

| Profile | The bot additionally... | Perks it exercises | Callings |
|---|---|---|---|
| `forge` | salvages every find, crafts the best piece it can afford each generation, brews the potion | `forge_fee_mult`, `craft_quality_mult`, `salvage_mult`, `brew_yield_mult`, `gather_mult`, `essence_mult` | armorer, bladewright, enchanter, runescribe, alchemist, hidewright, spiritbinder |
| `miner` | digs down a fixed shaft each generation to the `max_depth`/hazard limit, props when it can | `ore_mult`, `dig_mult`, `cave_mult` | delver, stonewright |
| `builder` | raises a house of the first size it can pay for, then the next, to the claim limit | `build_cost_mult`, `raid_mult` | stonewright, trapsmith, steadholder |
| `farmer` | buys young animals up to the ranch's pens, keeps them, sells or slaughters when grown | `farm_mult`, `keep_mult`, `value_mult`, `work_mult` | steadholder, wildcaller, breeder |
| `breeder` | pairs creatures, keeps the young, sells the surplus | `find_mult`, `fertility_mult`, `mutation_mult`, `value_mult`, `keep_mult` | breeder, wildcaller |
| `forager` | forages the nearest node each generation and hauls with companions | `forage_mult`, `haul_mult`, `carry_mult` | feastwright, greenwarden, wayfinder, caravaneer, delver |
| `fleer` | flees any fight under a hp share (it never does today) | `flee_mult` | trapsmith, wayfinder |

A profile never changes the **fights** (`GameBattle` still plays by `GameTactics`), so the existing 3-7% battle-death band still applies to the plain house with the profile on.

#### First measurement: the plain house on every profile (seeds 1-12, 8 races, 10 generations, 960 lives, commit 5d3521b)

| Profile | Gold at death | Gain (GE) | Actions | GE per action | Battle deaths |
|---|---|---|---|---|---|
| none (autopilot) | 4,775 | n/a | n/a | n/a | 2.7% |
| forge | 645 | 1,263 | 34.3 | 36.8 | 2.7% |
| miner | 4,808 | 963 | 28.6 | 33.7 | 2.3% |
| builder | 6,092 | 1,902 | 50.2 | 37.9 | 4.4% |
| farmer | 4,507 | 854 | 8.2 | 104.4 | 2.4% |
| breeder | 4,507 | 854 | 8.2 | 104.4 | 2.4% |
| forager | 4,775 | 1,347 | 27.2 | 49.5 | 2.7% |
| fleer | 4,293 | 876 | 0.9 | 876.2 | 5.3% |

Callings on their profile (same seeds, `keep`):

| Calling on profile | Gain (GE) | Actions | GE per action | Battle deaths |
|---|---|---|---|---|
| delver on miner | 1,062 (+10%) | 29.2 | 36.4 | 3.1% |
| stonewright on miner | 874 (-9%) | 27.2 | 32.2 | 3.3% |
| greenwarden on forager | 1,611 (+20%) | 26.7 | 60.4 | 4.4% |
| feastwright on forager | 1,618 (+20%) | 27.2 | 59.4 | 3.2% |

How to read it:
- **An autopilot life already gains about 850 GE** (gear and gold it holds at death), so a profile's own gain is its figure minus about 850: forge +410, miner +110, forager +500, builder +1,050. The farmer, breeder and fleer sit on the baseline.
- **Farmer and breeder are identical to the digit (854 GE, 8.2 actions): the breeder never reaches breeding in these runs**, so its numbers are the farmer's. Buying young animals at market price and valuing them at sell price gains nothing until they grow, and the policy rarely holds a pair of adults. This is a gap in the policy, not a result about the Breeder calling.
- **The fleer's 5.3% battle deaths** (against 2.7%) is the cost of fleeing under 35% health: the heir leaves a fight it was winning, and the effort is the 0.9 flights per life. `flee_mult` perks (Trapsmith, Wayfinder) are not yet run on it.
- **The builder moves the plain life itself**: gold at death 6,092 (+28% over 4,775), mean level 65 (against 59) and deaths 4.4%. A built house (bedroom rest, the forge it can hold) changes how the autopilot plays after it is built, so the builder's gain mixes the houses with a stronger life. Read it as an upper bound, and check what in the house does this before using it as a target.
- **The Stonewright's miner result (-9%) is noise.** Its power is walls, so the builder profile is its test; it has not been run.
- Delver and the two foragers read +10% to +20% on their profile, within the +-12% gold noise for Delver and above it for the foragers; they need the 24-seed re-run before any retune.
- **Not yet run:** the other callings on their profiles (armorer and the forge set, steadholder and wildcaller on farmer, breeder on breeder, trapsmith and wayfinder on fleer), builder with callings, and the synergy pairs.

### Metrics, per profile and calling (36 seeds, `keep`, 10 generations)

1. **`dGE`**: mean gold-equivalent per life of the calling run minus the plain house's, on the profile. Reported with its standard error across seeds (the same seeds both runs).
2. **`E`**: actions per generation the profile spent (identical for both runs unless the perk changes how many are needed).
3. **Return on effort** `dGE / E`, compared across callings *on the same profile*.
4. **`dR`**: change in battle-death share (points), the old measure; noise about 1 point per row on 960 lives (see *Method and noise*).
5. **Gold-at-death shift** (the existing column) to make sure a profile's gains do not leak outside the plan.
6. **Synergy**: the same measures with `keep` and the calling's *natural partner* items (the forty works, `GameSubclass.make`) for the `forge` profile, and with two profiles at once (`builder`+`miner`) to see whether the effects add or multiply. A synergy is a problem when `dGE(A+B) > 1.25 * (dGE(A) + dGE(B))`.

### Targets

- **Power**: a calling's `dGE` on its own profile is within **0.8x to 1.25x of the median calling's `dGE` on its profile** after pricing the effort (`dGE / E`), and the *whole-life* uplift (`dGE` summed over the profiles the calling is built for) is at most **+15% of the plain house's mean gold at death** (about 700 gold on the 4,775 baseline) so no calling is a second economy. These numbers are a first guess: they are the width of the existing gold noise (about +-12%) and should be set from the first measurement, not before.
- **Risk**: `dR` within +-1.5 points of the plain house on the same profile (the existing noise floor); a perk that buys power by making deaths 3 points likelier is a tradeoff to document, not a failure.
- **Manual effort**: the effort `E` of the best profile for a calling should be at most **2x** the plain house's profile `E` (a perk that makes the player do twice the work for the gain is a cost, and counts against it).
- **Autopilot options** (the baseline comparison): none of these perks may make the **autopilot-reachable** numbers move; the profile run changes nothing about the plain autopilot life (`test_game_subclass_roster` already checks that the unreached callings equal the baseline to the digit).

### Procedure

```bash
# the plain house on a profile, then each calling built for it; same seeds and races every time
godot --headless --path . -s res://tools/balance_harness.gd -- seeds=1-36 profile=forge subclass=none
godot --headless --path . -s res://tools/balance_harness.gd -- seeds=1-36 profile=forge subclass=armorer keep
...
```
Order: profile on the plain house first (that is the baseline for the profile); callings next; then a re-run of the ones that stand out on **24 new seeds** (as the sweep did for the five that stood out). Do not retune a perk from one 12-seed run. After a retune, re-run the *same* seeds and read the difference with the noise above in mind. Record the table in this file under the profile's name with the commit it was run on.

### Flagged: numbers missing for a full pass

- **Hooks (built)**: `GameBot.live_life(d, hook)`, `GameBot.flee_below` and `GameBot.on_fight_end` are off by default, so seeded lives do not move (`tests/test_game_profiles.gd`).
- **Gold-equivalent (built)**: `GameProfile.net_worth` prices the purse, materials (`GameShops.unit_price`), essences (40 per tier), pack and worn items (`GameItems.sell_price`), the roster (`GameRanch.sell_price`), built pieces (list cost) and potions (`potion_price`). Creature *work* (wool, eggs, venom per year) is not priced: a farm's yearly yield is invisible to it. That is the missing number for the farmer and breeder.
- **Effort counting (built)**: one action per dig, forage, craft, salvage, build, purchase, breeding order or flight. The mix is the policy's, not a measurement of a human.
- **Policies are first guesses**: the forge, builder, farmer and breeder rarely act (the bot is seldom in a town with a forge or market, and a 3x3 house costs 32 oak and 1 iron). Tune them before reading a calling's number against them.
- **Target band** for `dGE` (above) is still a guess; the first table gives the spread to set it from.
- The older table's claim that the autopilot "searches the dead (`gather_mult`, `essence_mult`, `drop_mult`, `rarity_mult`)" disagrees with `CLAUDE.md`, which says `GameBot` never calls `GameLoot.search_dead`/`GameCraft.after_search` (they are asked for by the screens). Resolve by reading `GameBot.step` before using those four keys as "autopilot-measured".

## Gold gaps: Hidewright and Trapsmith (re-run)

The first sweep (seeds 1-12) read the Hidewright's gold at death at -11% and the Trapsmith's at +12% of the plain house and marked both "unconfirmed". They were re-run on **24 new seeds (13-36), 8 races, 10 generations, `keep`, 1,920 lives each**, same arguments for every row:

```bash
godot --headless --path . -s res://tools/balance_harness.gd -- seeds=13-36 subclass=<none|hidewright|trapsmith> keep
```

| Row | Slain (of 1,920) | Mean level | Kills | Gold at death | vs plain house |
|---|---|---|---|---|---|
| none | 63 (3.3%) | 57 | 117.2 | 4,428 | +0.0% |
| hidewright | 68 (3.5%) | 56 | 114.7 | 4,391 | **-0.8%** |
| trapsmith (`hunt_gold_mult` 1.08) | 74 (3.9%) | 56 | 115.8 | 4,954 | **+11.9%** |
| trapsmith (`hunt_gold_mult` 1.05, after the change) | 71 (3.7%) | 57 | 117.5 | 4,732 | **+6.9%** |

**Where income and sinks diverge.** The autopilot's gold is almost all *hunt gold* (the fights' rewards, scaled by `hunt_gold_mult`) less what it spends on gear, potions and the temple; it digs, crafts and builds nothing. So a perk on a number in that path moves gold at death one for one, and a perk off the path does not move it at all.

- **Hidewright**: no perk on the gold path (`gather_mult`, `salvage_mult`, `defense_mult` 1.05, `carry_mult`). The -11% was noise (-0.8% on 1,920 new lives; the first run's own baseline moves about 12% between seed sets, see *Method and noise*). **Resolved: no change; not a gap.** (A thicker coat slightly lowers deaths, not gold.)
- **Trapsmith**: `hunt_gold_mult` 1.08 at founded strength (1.5x on the distance from 1) is **x1.12**, and +11.9% is that, to within noise. **A real gap, by design of the number.** The target margin for a perk that is *not* the calling's centrepiece is **under about +8% of the plain house's gold at death** (the same width the Wayfinder's `hunt_gold_mult` 1.05 gives, +7.5% founded, and the Caravaneer's buy/sell perks give). **Change: `hunt_gold_mult` 1.08 -> 1.05**, which is +6.9% measured (founded x1.075), with deaths unchanged (3.7%, in band) and the Trapsmith's real centrepieces (`raid_mult` 0.7, `flee_mult` 1.3) untouched.

**Target gold curve** (for a full pass; nothing beyond the margin above is decided): the plain house's mean gold at death is 4,428-4,775 depending on the seed set; a calling should sit within **+-8%** of it unless gold is its stated job (the Caravaneer, Steadholder, odd jobs), and the *shape over generations* should match the plain house's (no calling pulls ahead early and falls behind, or the reverse). The per-generation gold curve is **not printed by the harness** (it prints the mean at death only), so the shape check needs `Balance.detail` to also keep gold by generation; that is the missing number for a complete pass.

**Expected output of a re-run.** After the change the same command on seeds 13-36 should print the Trapsmith's gold within 4,430 +- 8% (4,070-4,780): measured 4,732. The Wayfinder, which shares the 1.05, should read near +7.5% against the same baseline (not re-run here). Any re-tune of a gold perk is re-run on the same seeds against the plain house **in the same session** (the baseline moves with the seed set, so only a same-seed pair is a measurement).
