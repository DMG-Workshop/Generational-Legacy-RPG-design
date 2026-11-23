# Trials

Status: **first slice built** (core, data, tests; no screen yet). ROADMAP item 67. Idea from the user: each world holds trials that take time and permanently improve the heir in one way each (body, mind, knowledge and so on), and each world can have its own.

## What a trial is

A place in a realm where the heir spends world time to pass a test. Passing it grants **one lasting gain**. A trial has a *focus* (what kind of gain), a *realm*, a *length* in world hours, a *gate* (level, class, or an earlier trial) and a *risk* (what failing costs). Each can be passed once per heir. A gain marked `legacy` also helps heirs.

## Focuses

| Focus | Enhances | Gain (examples) | Fit with what exists |
|---|---|---|---|
| Body | max HP, carry weight, injury and fatigue | +HP, +carry, a shorter recovery | `GameHeir` max HP, `GameItems` weight |
| Will | fear and status resistance, perception, stamina | resist rating, faster recovery | status effects in battle |
| Lore | a spell, feat, technique or recipe your class can use | one unlock, chosen by class from a list in data | `GameSpells`, `GameFeats`, `GameCraft` plans |
| Mastery | weapon or tool skill, evasion, action cost | accuracy, crit, a manoeuvre | feats and class skills |
| Spirit | favour, bloodline affinity, heirlooms | `legacy` gain that passes to heirs | `GameHeirloom`, bloodlines |
| Wild | terrain, weather, foraging, travel | less penalty in harsh biomes | `GameDay`, biomes, `GameForage` |
| Pact | big upside with a cost, flaw or scar | strong perk plus a drawback or upkeep | titles, scars |

New focuses are data, not code. Each realm lists its own trials (a Verdant Court trial of the seasons, a Hollow Below trial of the dark, a Clockwork trial of precision), with its own names, text and a gain drawn from the focus list.

## Rules (proposed)

- **Placement**: a pure function of the world seed and the realm, 3 to 6 trials per realm, never the dynasty's dice. Trials appear on the world map like landmarks.
- **Time**: a trial runs on the world clock (`pass_time`), so the day cycle, hunger and raids go on while the heir is in it. A trial can be left, which loses the progress.
- **Resolution**: a seeded check from the heir's own stats against the trial's difficulty, with a risk of a setback (hurt, a scar, a cost) on failure. Retry after a delay.
- **Gains are small and capped**: each focus has a cap per heir (`focus_cap` in data) so a long life cannot stack without limit. Pact gains must carry a drawback.
- **Lore is class-aware**: a Lore trial picks from a list of unlocks by the heir's class and skill; if none fit, it grants a generic technique.
- **Save**: only `trials_done` (ids) and any pending trial, written once something is done; old saves load clean; a damaged id is dropped.
- **Autopilot**: `GameBot` never starts a trial, so determinism and the golden fixture do not move. The `trialist` profile bot (`GameProfile`, `profile=trialist` on the balance harness) plays the trials to measure their return on effort; with no profile nothing changes.

## Balance

Measure each focus as gold-equivalent or risk saved per world hour, with `docs/BALANCE.md`'s profile bot method. Target: no focus is a clear best, and the whole set adds well under a calling's worth of power. Numbers are guesses until measured.

## Follow-ups and open questions

- How many trials per realm, and whether some are hidden until a hint is found.
- Whether failure can kill (proposed: no, only scars and costs).
- Whether companions can enter a trial with the heir.
- Interaction with titles (a title for finishing all of a realm's trials).

## Trial quest and trial-master

Every trial is reached through a **quest** and run by a **trial-master**, both in `data/world/trials.json` (text out of code).

**The quest.** A trial has `quest.steps`, done in order with `GameTrials.do_step`: `visit` (the heir stands at a place: the site is found), `offering` (pay gold, scaled by the generation like other prices: the right to enter) and `level`. A trial refuses to start (`start_block`) until every step is done, and the refusal is the master's own line naming the step still open. The way in is learned once by the family (`GameDynasty.trials.steps`) and sets the story flag `trial_<id>_way`, so `GameQuests` flag objectives can build on it. The trial itself is the quest's last step: its gain is given only when it is passed, and passing sets `trial_<id>`. Trial quests are not on any town board and are not in `data/quests`, so `GameQuests.bot_tick` and `GameBot` cannot offer or take them (the test checks it).

**The master.** Each trial names a creature of `data/creatures` (`master.id`) and a name. It speaks, from data: an `opening` line when the trial starts, one line per stage (`stage_line`, the stage follows the hours spent), then `success` or `failure`. A Mastery or Pact trial may set `fight: true`: after its hours it is won only by beating the master. `begin_master` builds the master as a foe of the heir's level (`master_level_mult`) with its trial name and starts it as a legend-style fight (so no sickness is rolled on the dynasty's dice); after `finish_battle` the caller runs `settle_master`, where a victory passes the trial and anything else leaves it to be fought again. The fight uses the battle's dice like any fight, and only a player ever starts one.

**Built.** Placement (`placed`, 3 to 6 per realm, a function of seed and realm only), quest, start, world-hour progress (`wait` feeds `GameClock`; a day is 24 hours of `GameDay`), the check on its own dice (`hash(seed, trial, heir, try)`), setbacks that never kill (`hurt` takes a share of max HP down to 1, `cost` takes gold) and a retry wait, capped gains read through `GameTrials.bonus` (hooked into `GameHeir.trait_total` and `GameCarry.capacity`, only for a heir with a trial passed), Lore picking a spell or feat the class suits (else a small fallback gain; at most `unlocks` per heir), Pact drawbacks, Spirit `legacy` gains passed to heirs, saves (`GameHeir.trials_done`, `GameDynasty.trials`, each written only once set, damaged ids dropped) and `tools/check_data.gd` validation. Data: 7 trials in the base world (`material`, one per focus), 5 in the Verdant Court, 5 in the Hollow Below.

**Not built.** A sandbox place for a trial, a title for finishing a realm, companions in a trial, a scar as a setback (a Pact's flaw is a stat drawback for now).

**Guessed numbers (all in data, none measured).** Gains: Body +4% max HP or +5% carry, Will +3% resist, Mastery +5% crit damage or +2% reflexes, Spirit +2% luck (legacy), Wild +4% stealth or +5% fire resistance, Pact +8% melee damage (or +10% max MP) against -5% max HP (or -3% resist). Caps per focus and stat are in `focuses.*.cap` (for example Body max HP 10%, Will resist 8%, Lore 3 unlocks). Lengths 3 to 8 hours, gate levels 3 to 11, offerings 30 to 80 gold, check difficulties 18 to 36 on a stat (chance is score over score plus difficulty, 15% to 90%), retry wait 12 hours. Wild gains use stats the game already reads (stealth, fire resistance) rather than a new terrain rule.


## The screen (built)

The House panel's **Trials** button opens a panel (`ui/play/trials_panel.gd`) that lists every trial standing in a realm whose gate is open, the one under way first, then those that can be begun, those with a way in to do, those that cannot be begun yet, and the passed. Each row says its name, focus, level and hours, who runs it, what passing gives (`GameTrials.gain_preview`: "max hp +4%", "a spell or feat your calling can use", the Pact's price, a Spirit gain passing to heirs) and the chance of passing, or that a fight decides it. A row shows the next step of its way in with a **Do this step** button (disabled, with the reason as text, when the heir is not at the place, short of gold or level), then **Begin** once the way in is done. A trial under way shows the master's line for the stage, the hours spent and to go, and **Let the hours pass** (the world clock runs: the day, hunger and raids go on), **Finish the trial** or, for a fight trial, **Face the master**, and **Leave** (asks twice; the progress is lost).

The panel computes nothing. A fight trial's battle is handed to the battle screen as any fight is, and `finish_battle` settles the trial afterwards. Not built: a trial shown on the map where it stands, the master drawn, and a trial offered by the people of a town.


## The profile bot (built)

`GameProfile`'s `trialist` (`docs/BALANCE.md` has the figures). Every fourth step it does one thing, through the calls the screen makes: with a trial under way, `wait_out` then `finish`; else `start` a trial whose way in is done; else `do_step` when the heir stands where the step asks, or one `GameDynasty.travel` hop along `route_to` the place it names. It takes the trials in the listing's order, skips a trial won by a fight (the autopilot's battle loop does not run `begin_master`), and does not pay for a way in whose gate (level, class, an earlier trial) the heir does not meet. Its effort is counted in actions; the harness line adds `trials N passed of M tried per life`. First measurement, 960 lives: 1.63 passed of 2.71 tried, gold at death -20%, level, age and battle deaths within noise of the plain autopilot. The harness line also counts what the trials cost (gold paid, gold the clock took, hours waited, road hops): about 35 gold, 17 hours and one road hop a life. The gold gap was traced (BALANCE.md): it is not the cost and not the gains, it is the autopilot being left away from its home board. It draws no die of the dynasty's (`GameTrials.dice` is keyed on the seed), so a life with the profile off is the autopilot's, and the golden fixture is untouched.

## On the map, and the masters' art (built)

- **The world map** (`GameWorldMap.trial_markers`, drawn by `ui/play/world_map_panel.gd`): a triangle for every trial of the open realm (`material`) whose site the family has found, that is, whose first step of the way in is done (the step that "finds the site"), or that the heir has passed (green). The site is the trial's place in its 256-square stretched over the world and moved to the nearest cell that is not water (`GameWorldMap.trial_tile`; a pure function of the seed, nothing saved). A line under the map lists them, as the wilds' landmarks are. The Verdant Court and the Hollow Below are spaces of their own and are not on this map.
- **The masters** are drawn in the Trials panel: each row has a framed portrait of the creature that runs the trial, the same pixel art the fight shows (`SpriteArt.creature`; all twelve master creatures have art). A master is a creature of `data/creatures`, so there is no art that belongs to a master alone: a trial's master looks like its creature, and two trials may share one (the Moss Stag runs two). Own art for the seventeen masters is built below; a portrait on the battle screen is not.

## The payoff, measured

Whether the trials pay for themselves was tried with the profile bot and the harness (`docs/BALANCE.md`, the trialist's variants). The answer is that the autopilot cannot tell: with the trials free, with their gains at nothing and with their gains tripled, the plain autopilot's numbers do not move apart from the gold the bot loses by leaving its home town. A trial's price is small (about 35 gold, 17 hours and a road hop a life) and its gain a few percent of one stat, capped by focus, which is well under a calling's worth as the design asks. **No gain, cost or cap was changed.** If the gains should be larger or the costs smaller, that is a design decision for the numbers on paper, and the place to make it is `data/world/trials.json` (`gain`, `risk`, the offerings in `quest.steps`, `focuses.*.cap`).

## Masters' art (built)

Every trial's master has a look of its own (`data/art/masters.json`, drawn by `SpriteArt.master(trial_id)`). A master is still a creature of `data/creatures` (that is what fights, and what the check and the foe come from), so its look is **that creature's sprite repainted**: a `palette` that replaces colours of keys the sprite already has (so no more colours than the style allows) and, for some, `marks`, a few pixels inside the silhouette in colours of their own (the Ring Champion's war paint, a gold rune on the Archivist's robe, rules on the Ledger Keeper's, the Pack-Mother's scar). So the Stone Warden is a mossy golem, the Pale Keeper an ember-coloured wraith, the Barrow Warden a green one with red eyes, and the two Moss Stag masters are spring and autumn; no master is the plain creature a player meets in the wild, and the two that share a creature differ. The Trials panel's portrait draws the master's look, and the fight with a master draws it too (`GameTrials.begin_master` puts `master_of`, the trial id, on the foe; `BattleView` reads it and falls back to the plain creature). `SpriteArt.validate` checks every master (a real trial, a creature with art, palette keys that creature has, marks inside the silhouette, never identical to the plain creature, and every trial has one) and `style_problems` holds each repainted image to the same rules as a creature (outline, no stray pixels, the colour cap, margins); `tools/art_sheet.gd -- what=masters` draws them together. `tests/test_game_master_art.gd` checks. **Not built:** sprites drawn from scratch for a master (new shapes, crowns, staves, bigger bodies: those need new pixel art and an art review), animation of its own, and a master on the world map or in the sandbox.
