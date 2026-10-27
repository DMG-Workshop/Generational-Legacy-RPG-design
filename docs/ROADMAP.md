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
