# Roadmap

## Text game: the queue

In order:

1. **Feats.** Done. Non-spell damage feats, feat points and slots, loadouts changed only in towns or after a rest. Includes the **auto-battle toggle**: once turned on, Hunt and Hard hunt fight themselves until the player turns it off.
2. **Battle-side diseases.** Done. Looting corpses, coating blades with toxins, throwing plague vials, sickness spreading between companions.
3. **Whole-game bug hunt.** Done. UI, saves, balance and long runs, across every system.
4. **Skill trees.** Done. Trees for the heir and for companions, with some nodes passing down the bloodline.
5. **Mobile: Android and iOS.** Done, apart from testing on a real device. The same Godot project, exported to phones and tablets. The game logic and data stay as they are; the work is in the screens:
   - Export setup for Android (built on Linux with the Android SDK and a signing key) and iOS (built on a Mac with Xcode; installing on an iPhone or publishing needs an Apple Developer account).
   - Touch instead of hover: everything that shows details on mouse hover (traits, feat and spell previews, tavern, shop and map details) also shows them on tap-and-hold.
   - Readable on a phone: a text-size setting and larger buttons, with layouts checked on small screens.
   - Landscape lock, so the 1280x720 layout fills the screen.
   - Saves, auto-battle and the autopilot checked on a real device.
6. **Party commands.** Done. In manual mode a battle with companions steps through each member (the heir, then every companion, from their own class skills, spells, feats and the shared potions), queues the choices and plays the round together on Fight!. Per-member Auto (remembered), Repeat last round, Back, a Flee that covers the party, and a party strip showing who is asked and what is queued. A solo hunt and the master Auto-battle play exactly as before.

Also done: the autopilot takes Hard hunts once its heir is clearly strong, which keeps battle deaths in the 3-7% band now that skill trees make heirs stronger.

## Running list of updates

A running backlog for the text game. Add new ideas at the end; mark an item done when it lands.

**Done**
- **Auto hunt keeps going.** With Auto-battle on, a finished hunt starts the next one of the same kind by itself after a short pause. It stops when the player presses Stop (on the result, or "Stop after this fight" during it), takes over, or when the heir's health is under half (`balance.json` "auto_hunt").

**Fixes and known gaps**
1. **Commit the balance harness**, so the 3-7% death band can be re-checked after any change. Done: `tools/balance_harness.gd`, described in `docs/BALANCE.md`. It is a new tool, so its figures are its own baseline.
2. **Lift battle deaths into the band.** Closed, no change needed. The 40-seed run (3,200 lives) gives 3.4% slain in battle, 95% range 2.9-4.1%, inside the band. The "seeds near 2.5%" were noise: single 80-life seeds ran from 0% to 10% and 19 of the 40 fell under 3% by chance. See `docs/BALANCE.md`.
3. **Lifespan-scaled death hazard for long-lived races** (elves, gnomes). Not needed by the numbers: dwarf, elf, gnome and halfling sit at 4.7-5.2% against 3.5% for humans, inside the band, so a long life does not stack up too many chances to die. What the 40-seed run did show is the opposite end, left as a design question: the autopilot almost never loses an orc (0 of 376) or a beastkin (1 of 378), because they die of old age before its Hard hunt rules (level 40 and up) apply.
4. **Fix the occasional tooltip-hold test failure** in `test_game_mobile.gd` at its timing cause. Done: after a tap rebuilt the screen, the test aimed its finger at a button its container had not yet placed (Godot lays containers out in a deferred call), so the hold could land on the button drawn underneath. The `_hold` helper now waits a frame before aiming.
5. **Stop the arena jumping during party rounds.**
6. **Remove or archive the older prototype code** (`core/battle`, `world/`, `ui/screens` and the GutTest suites).

**Build and release**
7. **CI that runs the game suites on every PR.** Done: `.github/workflows/tests.yml` runs each suite in its own job, and fails one that prints `SCRIPT ERROR` even if it exits 0. Still to do in the repository settings: mark the **All game suites** check as required.
8. **A release workflow** that builds the Android APK and the Windows exe and attaches them to a GitHub release. Done: `.github/workflows/release.yml`, described in `docs/RELEASING.md`. Publishing a release runs it. The APK is debug-signed, with a one-off key per build unless the repository has a keystore secret.
9. **A signed release APK** with a real keystore, for the Play Store.

**Player experience**
10. **A first-heir tutorial:** Hunt, Rest, Train, founding a family and the first succession. Done: a one-line tip strip above the life screen's actions names the next thing to do and marks its button, and the succession screen carries the last tip. The tips come from the game's own state (so old saves need nothing), are written in `data/ui/tutorial.json`, and are switched off by Skip tips, by choosing the first heir, or under Menu > Tutorial tips.
11. **Several save slots and a backup export.** Done: three slots on the title screen (slot 1 is the existing save file), each saved atomically with a `.bak` it falls back to, and a text backup that Copy backup puts on the clipboard (title screen and game menu) and Restore backup reads back into any slot. Covering or erasing a house asks first. Backups pass through the clipboard only; a file export for phones is not built.
12. **A family tree viewer:** ancestors, traits, deaths and legacy echoes. Progress: a Family Tree tab in the chronicle shows each generation with parents, spouse, children, deaths, traits and the echoes from that generation (`GameFamilyTree`). Heirs folded into the Ages are counted, not named.
13. **A dynasty statistics screen:** deaths by cause, best heir, Ages reached, gold over time.
14. **Accessibility options:** colour-blind palette, high contrast, reduced motion.
15. **Sound and music:** battle cues, a death sting, ambient tracks per Age.

**Game systems**
16. **Achievements and dynasty milestones.**
17. **Faction reputation in the text game**, so NPCs judge the heir by their ancestors.
18. **Heirloom upgrades across generations.**
19. **Random world events per Age:** wars, famines and golden ages that change hunts, shops and diseases.
20. **Hard-mode dynasty options:** whole-line permadeath, iron-man saves, a generation cap.
21. **A family house that grows across generations.** Upgrades bought between hunts and passed down the line: more party slots, crafting, better training and shops. Idea from the base between expeditions in *The Shattered Isles*, fitted to the dynasty. Builds on item 18 (heirloom upgrades) and the persistent estates the README promises. Progress: the core rules and the first two tracks (Hall and Training Yard) are in, and the House button on the life screen buys them. The autopilot does not buy upgrades, so the battle figures do not move with the screen.
22. **Reactions that ask first.** When a hurt party member is about to be hit, the player is offered a reaction such as "Cover this ally?"; a member on Auto decides for itself. Idea from *The Shattered Isles*, fitted to party commands. It changes battle results, so it is a balance change: show before and after numbers.

## After the text game: the 2D/3D sandbox

Starts only once the text game is complete. The text game's systems (lineage, Fate, battles, diseases, companions, Ages) carry over: logic stays apart from rendering, so the new world is a new view on the same core.

### Look and shape
- An **open-world sandbox**, in the spirit of Minecraft, Terraria and RimWorld.
- **Isometric pixel-art 2D, running on 3D code**: a real 3D world drawn as isometric pixel art, so height, digging down and building up are real.

### Harvesting
- Wood, rock, plants, food and fruit, meat from creatures, ores, minerals, gems and many kinds of fluids.
- **Finite nodes that come back.** A tree or an ore vein gives a few items, then disappears. It respawns after a while, unless the player has built over the spot.

### Mining
- Mining is a headline system that should go beyond any other mining game: depth, strata, what lies under the ground and how digging changes the world.
- **Digging into the underworld.** Mining down from the overworld slowly changes the ground around the shaft until it becomes a gateway: the player passes from the overworld into the underworld and the two connect there.

### Crafting
- A **one-of-a-kind crafting system**, designed to stand on its own rather than copy a recipe grid.

### Worlds and spaces
- **Gateways to other worlds** (the realms).
- **World-space IDs.** Every space has its own ID. Entering a building loads its interior as its own space, like a small dimension of its own. The same mechanism carries the underworld and the other worlds.

### Mods
- **Mod support.** Players can load their own mods or other people's, each in their own game. Content is already data-driven (JSON), which is the base for this.
