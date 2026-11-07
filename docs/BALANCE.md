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
