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
13. **A dynasty statistics screen:** deaths by cause, best heir, Ages reached, gold over time. Progress: a Statistics tab in the chronicle shows heirs lived, generations and Age, deaths by cause, legends slain, the greatest heir and the gold of each heir kept in full (`GameStats`). Gold over time: each Age keeps the total gold its heirs had at death, so the Statistics tab shows the average per Age, folded heirs included. An Age saved before this shows as not recorded.
14. **Accessibility options:** colour-blind palette, high contrast, reduced motion. Progress: the menu's Accessibility row turns on colour-blind colours (blue and orange for good and bad), high contrast (brighter quiet text) and reduced motion (no sliding or lunging in fights). The choices are stored in settings.cfg, not in the save.
15. **Sound and music:** battle cues, a death sting, ambient tracks per Age.

**Game systems**
16. **Achievements and dynasty milestones.**
17. **Faction reputation in the text game**, so NPCs judge the heir by their ancestors.
18. **Heirloom upgrades across generations.**
19. **Random world events per Age:** wars, famines and golden ages that change hunts, shops and diseases.
20. **Hard-mode dynasty options:** whole-line permadeath, iron-man saves, a generation cap.
21. **A family house that grows across generations.** Upgrades bought between hunts and passed down the line: more party slots, crafting, better training and shops. Idea from the base between expeditions in *The Shattered Isles*, fitted to the dynasty. Builds on item 18 (heirloom upgrades) and the persistent estates the README promises. Progress: the core rules and the first two tracks (Hall and Training Yard) are in, and the House button on the life screen buys them. The autopilot does not buy upgrades, so the battle figures do not move with the screen.
22. **Reactions that ask first.** When a hurt party member is about to be hit, the player is offered a reaction such as "Cover this ally?"; a member on Auto decides for itself. Idea from *The Shattered Isles*, fitted to party commands. It changes battle results, so it is a balance change: show before and after numbers. Progress: a standing version is in. In a party round each member's Cover button picks someone to cover; when a foe swings at that member below 30% of their health (`cover_below` in rounds.json), the coverer takes the blow instead, once a round. It is set before the round and kept from round to round, with no pause yet. The autopilot and auto-battle never set a cover, so their results and the balance figures do not change. The prompt is in too: when a foe is about to strike a member below 30%, the round stops and asks which member on manual control steps in front, once per covered member a round; "Let it land" plays exactly as before. Still to do: members on Auto deciding to cover for themselves, which changes results and needs balance numbers.

**Before the 2D/3D sandbox: groundwork**

Proposed order: items 23 to 26 first (they change how saves and views work, and get harder later), then the rendering trial (36), then the world systems in text (41 onwards) while the art catches up.

23. **Save versioning.** Done (`GameSaveVersion`). A save version number and a chain of tested upgrade steps from each version to the next. Today old saves load because new keys are optional; world chunks, inventories and positions need more than that.
24. **Saving in the middle of a fight.** A battle, and a round waiting on a question, saved and loaded exactly. A phone can close the app at any moment, and the sandbox needs mid-action state anyway.
25. **A fixed list of events for views.** Done for the battle: every typed event a fight emits is listed with its fields and kinds in `data/game/battle_events.json` (`GameEventSpec`), and `tests/test_game_event_list.gd` checks that each event played and each type in the source is on the list. Life actions return text lines and emit no typed events; they move to keyed data with item 28. The isometric view becomes a second renderer on the same events as the text screens.
26. **Cosmetic randomness kept apart.** Visuals (particles, idle animations, camera shake) get their own random numbers, never the dynasty's, with a test that the golden digests are the same with the view on or off.
27. **A world clock apart from actions.** Today years pass per action; the sandbox runs in time. One clock that both can drive, so ageing, disease, upkeep and the Ages keep working.
28. **Text out of code, and one data check.** The log lines and messages in `core/game` move into data with keys (ready for translation and sound cues), and one command runs every data validator, in CI.
29. **Replay files.** A run's seed and commands saved to a small file and played back exactly: bug reports from players, the balance harness, and proof that the new view keeps determinism.
30. **Long runs on a schedule, with budgets.** The autopilot playing many dynasties to the end every night, tracking deaths, save size, load time and time per generation against set limits, so performance limits are known before the world adds load.
31. **Save files beyond the clipboard.** Export and import a save file (the share sheet on phones), and optional cloud sync. World saves will outgrow the clipboard backup.

**Before the 2D/3D sandbox: art and presentation**

32. **Battle sprites from data.** Done. Pixel figures for every creature (the five bosses included), race and class, stored as text grids in `data/art/` and drawn on the battle screen in place of the blocks (`ui/play/sprite_art.gd`, `docs/ART.md`). The same art and pipeline feed the isometric world. Also done with it: every hero and companion wears a shirt colour of their own, picked for them or chosen on the Looks screen, and every fight is drawn in front of the land it is fought in, with its weather and season (`ui/play/scenery_art.gd`).
33. **Animation states.** Done as poses on the sprites, driven by the battle's events (`ui/play/figure_pose.gd`): figures breathe when standing, hop to attack and cast, flinch when hurt, step back to dodge, crouch to guard and fall when knocked out or slain, in whole pixels of the art. Reduced motion stills them. Drawn frames for a figure can replace a pose later.
34. **An art style guide and texture atlases.** The palette, outline, light, sizes and facing rules written down, so new art matches; generated textures packed into atlases when a screen loads.
35. **Screenshot tests.** A CI job that renders key screens under a virtual display and compares them with stored images, so changes to the UI or the art are seen in review.
36. **A rendering trial on a real phone.** A throwaway isometric pixel-art scene in Godot's 3D (orthographic camera, pixel snapping, sprites and lights) on the target Android phone: frame time, battery, heat and APK size. Then decide the technique, and how art files are stored (Git LFS, import settings), before making art for it.
37. **Graphics settings.** Quality presets (pixel scale, effects, frame cap) and a battery saver, ready for the 3D renderer.
38. **Gear shown on figures.** Done. The heir's weapon and armour change their figure (`data/art/gear.json`): metal, wood and leather finishes land on the weapon or the armour only, magic weapons glow, and plate, vestments, shadow weave, dragonscale and barrow plate hang a cape. Gear drawn as its own layers (a different weapon shape, a helmet) is still to come.
39. **Input for a world.** Movement, camera, digging and building by touch, mouse and keyboard, and gamepad. Reduced motion and the colour-blind colours carry over.
40. **Localisation.** Translation files for every player-facing text, a font that covers the target languages, and a pseudo-language test that catches text that no longer fits.

**Before the 2D/3D sandbox: world systems, settled in text first**

The text game is the cheap place to get these rules right: they are core rules and data with headless tests, and a text screen where one helps.

41. **World spaces and coordinates.** The roadmap's world-space IDs given to towns, dungeons, the house and interiors now, with map positions, so travel already speaks the sandbox's language.
42. **One item and material list.** Stable IDs and tags (material, tier, stack size, weight) for every item, validated, so harvesting, mining and crafting extend one list.
43. **Inventory with stacks and weight.** Built on item 42, with carry limits; the text game can use it for loot first.
44. **Gathering and crafting.** The "one-of-a-kind crafting system" designed as rules and data with a text screen, so the sandbox inherits a tested system.
45. **Mining as data.** Strata, ores by depth, and how digging changes the ground, all testable without graphics.
46. **World generation from the dynasty's seed.** Biomes, terrain, strata and the placement of nodes and ores, the same for the same seed, checked headless.
47. **Spawn tables.** Which creatures appear where and when, by biome, depth and Age, as data; hunts can use them before the world does.
48. **Creature behaviour as data.** Wander, chase, flee, guard and swarm rules by tag, tested headless, so creatures in the open world need no hand-written code each.
49. **Pathfinding over dug and built ground.** A grid and height pathfinder that digging and building change, with headless tests.
50. **Building and placement rules.** What can stand where (support, height, rooms), grown from the family house (item 21), which becomes the first base.
51. **Day, night and weather.** A cycle on the world clock (item 27), with weather that changes hunts and the look of the world; battles already have weather.
52. **Companions in the world.** Following, idling and helping (gathering, guarding), built on the party rules.
53. **Sandbox tips.** The first-heir tips extended to moving, digging and building, from data like today's.
54. **Desktop builds and crash reports.** Windows, Linux and macOS exports with gamepad menus, store images from the screenshot tool, and opt-in error reports that carry a save, so problems on phones can be reproduced.

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
