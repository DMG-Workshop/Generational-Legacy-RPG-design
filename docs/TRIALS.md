# Trials

Status: **design, not built.** Queued as ROADMAP item 67. Idea from the user: each world holds trials that take time and permanently improve the heir in one way each (body, mind, knowledge and so on), and each world can have its own.

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
- **Autopilot**: `GameBot` never starts a trial, so determinism and the golden fixture do not move. A profile bot (`GameProfile`) may gain a `trials` profile to measure return on effort.

## Balance

Measure each focus as gold-equivalent or risk saved per world hour, with `docs/BALANCE.md`'s profile bot method. Target: no focus is a clear best, and the whole set adds well under a calling's worth of power. Numbers are guesses until measured.

## Follow-ups and open questions

- How many trials per realm, and whether some are hidden until a hint is found.
- Whether failure can kill (proposed: no, only scars and costs).
- Whether companions can enter a trial with the heir.
- Interaction with titles (a title for finishing all of a realm's trials).
