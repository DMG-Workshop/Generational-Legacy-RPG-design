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

Default arguments (seeds 1-12, 10 generations), at the commit that added the harness:

| | Lives | Slain | Share | 95% range |
|---|---|---|---|---|
| Overall | 960 | 35 | 3.6% | 2.6-5.0% |

By race of the heir:

| Race | Lives | Slain | Share |
|---|---|---|---|
| beastkin | 102 | 1 | 1.0% |
| dragonborn | 102 | 3 | 2.9% |
| dwarf | 131 | 5 | 3.8% |
| elf | 118 | 5 | 4.2% |
| gnome | 123 | 8 | 6.5% |
| halfling | 110 | 7 | 6.4% |
| human | 125 | 4 | 3.2% |
| orc | 105 | 0 | 0.0% |
| half_dragon | 17 | 0 | 0.0% |
| half_elf | 10 | 2 | 20.0% |
| half_orc | 17 | 0 | 0.0% |

The overall share is inside the band, and its range reaches below the 3% floor. Within the sampling noise, the orc (shortest lived) stands out for never being slain, and the gnome and halfling sit near the 7% ceiling.
