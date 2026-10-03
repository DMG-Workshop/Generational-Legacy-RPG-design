# Generational Legacy RPG — Game Design Document

Oct 2, 2026 · @Dennis the Leprechaun

## Vision and Core Premise

The player lives one family's life across 999 generations in a high-magic fantasy world: you play a full life, have children, then continue as one of your kids while your old character becomes an NPC parent. Every choice ripples forward through traits, curses, wealth, reputation, and the world itself.

At roughly 25 years per generation, the saga spans about 25,000 years of in-world history. The world is the second main character: civilizations rise and fall, magic changes, and the first ancestor becomes legend, then myth, then possibly a god.

### Design pillars

- **Legacy is the game.** Traits, debts, heirlooms, estates, and reputations pass down and compound.
- **Failure is playable.** Heirs can fail at random; a failed life is a story, never a game over.
- **The world remembers.** NPCs, factions, creatures, and the land react to what your ancestors did.
- **Kids can reject their legacy.** Any heir can embrace, rewrite, or abandon the family path.
- **Romance is flavor.** Marriage exists to continue the line and add color, not as a core system.

## Genre and Presentation

| Aspect | Decision |
|--------|----------|
| Genre | Traditional RPG, a hybrid of classic JRPG and CRPG |
| Battles | Classic Final Fantasy side-view, front and back rows |
| Exploration | 2D side-view, Terraria-style: dig anywhere, build anything |
| Worlds | Multiple realms linked by teleport systems |
| Setting | High magic: magical creatures, peoples, weapons, and armor everywhere |
| Future version | Isometric 3D, reusing the same systems and data |
| Length | 999 generations, with variable play depth per life |

## The 999-Generation Structure

Playing every life in full would take hundreds of hours, so each generation is played at a depth that matches how much is happening in it.

### Lifetime depth modes

| Mode | What the player does | Used for |
|------|---------------------|----------|
| Full Life | Plays childhood to death: every quest, dungeon, and fight | Pivotal generations, failures, curse activations, prophecies |
| Chronicle | Plays 5 to 10 key moments; the gaps are simulated | Eventful but not pivotal lives |
| Echo | Life auto-plays from traits and personality; player makes 2 or 3 big decisions | Quiet generations |
| Legend Skip | Several generations summarized at once | Calm stretches; stops automatically when something big triggers |

The game forces Full Life mode when a failure, curse activation, or prophecy fires, so important moments are always hands-on.

### The Ages

| Age | Generations | Flavor |
|-----|-------------|--------|
| Age of Wild Magic | 1 to 100 | Primal magic, dragons rule, humans are small |
| Age of Kingdoms | 101 to 250 | Mage-kings, great houses, holy wars |
| Age of Empire | 251 to 400 | One empire; magic codified and regulated |
| The Sundering | 401 to 500 | Catastrophe; magic breaks, monsters return |
| Age of Ash | 501 to 650 | Survival, scattered city-states, lost knowledge |
| Age of Rediscovery | 651 to 800 | Ruins excavated, ancient magic relearned |
| Age of Arcane Industry | 801 to 950 | Magitech, airships, golem armies |
| The Final Age | 951 to 999 | Everything converges on the Covenant |

### Memory decay

How the world remembers an ancestor depends on how long ago they lived.

| Time since death | How they are remembered |
|------------------|------------------------|
| 1 to 3 generations | Personal memory; people knew them |
| 4 to 20 generations | History: recorded, debated, sometimes wrong |
| 20 to 100 generations | Legend: exaggerated, sung, rival versions |
| 100+ generations | Myth or religion: worshipped, feared, or forgotten |

A Gen 600 heir might visit a temple to their own ancestor and find the priests have the story completely wrong.

### Narrative frame: the Long Covenant

The first ancestor made a pact with something ancient (a dying god, a world-serpent, or the Fae Queen) that binds the bloodline for exactly 999 generations. The terms are forgotten within a few hundred years. Clues surface across the Ages, and at Gen 999 the Covenant comes due; every choice made across 25,000 years decides the outcome.

**Open question:** which entity made the Covenant, and what does it want at the end?

## Trait System

Traits are the living bloodline: they pass down, mutate, go dormant, and resurface, and they drive both mechanics and story hooks.

### Trait anatomy

Every trait defines: name, source (inherited, acquired, cursed, blessed), expression (how it shows in this person), mechanical effect, inheritance rule, mutation chance, and a story hook.

### Bloodline traits (inherited core)

| Trait | Effect | Inherit | Possible mutations |
|-------|--------|---------|-------------------|
| Mageblood | +20% power in its element; unlocks mage guild | 60% | Ice Mage, Wild Mage, Burnt Out |
| Dragonblood | Slow aging, dragon-fire resistance, draws dragon attention | 70% (20% skips 2 gens) | Draconic Form, Dragon-Slayer |
| Faetouched | Sees through glamours, 50% longer life, fae magic | 80%, always with a contract | Fully Fae, Iron-Bound |
| Noble Blood | +25% persuasion, titles and land claims | 100%, with debts and expectations | Bastard, Usurper, Outlaw |
| Craftmaster's Hands | Craft 25% faster, 15% better quality | 75% | Artificer, Saboteur, Artisan's Curse |
| The Sight | Prophetic visions, foresee some outcomes | 50% | Oracle, Blind Spot, Silenced |
| Warrior's Steel | +30% melee damage, faster reflexes; atrophies without battle | 65% | Berserker, Pacifist, Scarred |
| Marked by Death | One extra life; undead and reapers seek you | 40% | Undead, Death Knight, Life Thief |
| Outlaw's Cunning | +20% stealth and theft, criminal contacts | 70% | Legendary Thief, Law Bringer, Caged |
| Divine Favor | Miracles and deity favor; 50% chance it is a curse instead | 55% | Chosen One, Fallen, Neutral |

### Acquired traits (earned this life)

Scarred, Cursed, Blessed, Indebted, Betrayed, Legendary, Magically Burned, Monster Hunter, Oath-Sworn, Lost Love. These pass down at lower rates (10 to 40%) and mostly shape personality and story hooks; some, like Indebted and Oath-Sworn, can pass at up to 100% when magically binding.

### Curse traits (active supernatural debts)

Fae Contract, Blood Debt, Lich's Binding, Werewolf or Vampire Curse, Possession, Prophecy Binding. Each is a quest engine with explicit resolution paths: fulfill, negotiate, break, or embrace.

### Blessing traits (gifts with costs)

| Blessing | Benefit | Hidden cost |
|----------|---------|-------------|
| Saint's Blood | +30% healing, purify curses | Enemies of the faith hunt you; can't lie well |
| Dragon's Favor | Dragons won't attack, can call for aid | Dragons collect their debts |
| Lucky | +15% to all rolls | Fate may balance it with bad luck later |
| Immortal Youth | +50 years of life | You outlive everyone you love |
| Magical Savant | Learn spells 50% faster | Magic addiction, burnout risk |

### Inheritance rules

| Trait type | Base chance to pass |
|-----------|-------------------|
| Bloodline | 40 to 80% |
| Acquired | 10 to 40% |
| Curses | 50 to 100% |
| Blessings | 30 to 60% |

| Modifier | Effect on chance |
|----------|-----------------|
| Parent had 2+ related traits | +20% |
| Parent spent their life strengthening the trait | +30% |
| Parent actively rejected the trait | -30% |

Conflicting traits create friction rather than cancelling out. Examples: Mageblood + Magically Burned (a mage who lost magic), Noble Blood + Outlaw's Cunning (welcome in courts and the underworld, trusted by neither), Warrior's Steel + Pacifist (-40% warrior skills, +20% diplomacy), Faetouched + Divine Favor (fae and divine forces fight over you).

### Trait conflicts

Conflicting traits create friction rather than cancelling out. Examples: Mageblood + Magically Burned (a mage who lost magic), Noble Blood + Outlaw's Cunning (welcome in courts and the underworld, trusted by neither), Warrior's Steel + Pacifist (-40% warrior skills, +20% diplomacy), Faetouched + Divine Favor (fae and divine forces fight over you).

## Fate and Failure

Every character is born with a hidden Fate Value between 1% and 30%: their total chance of a major random failure over their whole life. Across 999 generations with an average near 15%, expect about 150 failing generations, roughly one every six or seven lives.

### Rolling Fate at birth

| Factor | Modifier |
|--------|----------|
| Base roll | 1 to 20% |
| Lucky or Blessed trait | -3 to -5% |
| Cursed, Marked by Death, Fae Contract | +5 to +10% |
| Parent suffered a critical failure | +5% |
| Born during war, plague, or the Sundering | +3% |
| Born in a peaceful era to a stable family | -3% |

The final value is always clamped to 1 to 30%.

### Milestone checks

The lifetime chance is split across five milestones: coming of age, first major quest, family founded, midlife, and elder years. The per-check chance is:

p_{check} = 1 - (1 - P_{life})^{1/5}

A 30% character has about a 6.9% chance per milestone; a 1% character about 0.2%.

### Severity

If a failure triggers, a second roll sets severity, leaning worse as Fate rises.

| Fate range | Likely severity |
|-----------|-----------------|
| 1 to 10% | Mostly minor: exile, injury, business ruin, guild expulsion, public shame |
| 11 to 20% | Mix of minor and major |
| 21 to 30% | Real chance of critical failure |

**Critical failure types:** Magical Catastrophe, Military Defeat, Betrayal by Ally, Curse Activation, Loss of Power, Family Tragedy, Heresy, Dragon Encounter. Each has mild, severe, and catastrophic outcomes and can shorten lifespan by 10 to 30 years.

### What the player sees

The exact number stays hidden. A seer, birth omen, or star chart reveals a tier.

| Omen tier | Fate range |
|-----------|-----------|
| Charmed | 1 to 5% |
| Steady | 6 to 12% |
| Uncertain | 13 to 20% |
| Ill-Starred | 21 to 30% |

### Random fate vs. player choice

The 1 to 30% covers only random failures. Choice-driven failures sit outside the cap: forbidden magic, breaking an oath, betraying an ally. A Charmed heir can still fall through reckless play; an Ill-Starred heir can survive through caution, protective charms, or rituals that lower Fate. Unstable rifts temporarily raise the roll for that moment.

### How failure shapes the next heir

Failure transforms the next generation's starting state: wealth, reputation, inherited traits, lifespan, and quest hooks. The next heir tends toward one of six archetypes.

| Archetype | Drive |
|-----------|-------|
| Restorer | Reclaim what was lost |
| Rebel | Do the opposite of the parent |
| Inheritor | Succeed where the parent failed |
| Survivor | Stay safe, trust no one |
| Redeemer | Heal the parent's wounds or curse |
| Successor | Keep what worked, fix what didn't |

## Family History and World Memory

Every significant ancestral act creates a Legacy Echo that changes how NPCs, factions, creatures, and the land treat descendants.

### Legacy Echo structure

Each echo records: who remembers, what was done, how they feel (grateful, angry, fearful, indebted, vengeful), the reputation effect on heirs, how fast memory decays, and what triggers it.

| Echo | Who remembers | Heir effect | Decay |
|------|---------------|------------|-------|
| Dragon Slayer | Dragons, dragon-slayers | -15 dragons, +20 slayers | Dragons: centuries; others: ~50 years |
| Traitor to the Crown | Royal court, rebels | -30 court, +20 rebels | Court: forever; commoners: ~30 years |
| Savior of the Village | Villagers, bards | +40 villagers, free lodging | Villagers: forever |
| Oath-Breaker | The oath-giver | Heir inherits the oath | Immortals: forever |
| Cursed the Land | The land, druids | Crops fail, animals flee in that region | Until broken |
| Hidden Child | Secret lover's family | A secret sibling may appear | Until discovered |
| Great Inventor | Scholars, mages | +25 scholars; people covet the creation | Centuries |
| War Criminal | Victims' descendants | -50, hunted for justice | Generations |

### Reputation

Starting reputation is inherited, then modified by the heir's own actions. An heir can lean into the legacy (amplifying it) or fight it (slowly rebuilding), and factions track both.

### Factional memory

| Faction | Remembers | Strong legacy | Bad legacy |
|---------|-----------|--------------|-----------|
| Mage's Circle | Spells, oaths, failures | Fast-tracked advancement | Harder tests or banned |
| Thieves' Guild | Heists, betrayals, debts | Automatic membership | Hunted or given suicide jobs |
| Warrior's Order | Battles, oaths, defeats | War stories, weapon bequests | Assumed cowardly |
| Church | Miracles, heresies | Blessings, quest priority | Excommunicated |
| Draconic Council | Dragons slain or befriended | Parley, aid | Attacked on sight |
| Noble Houses | Alliances, marriages, duels | Land claims, allies | Disgrace, no claims |

### Legacy quest hooks

The world generates quests from history: an old knight calling in a parent's debt of honor, a widow seeking vengeance for a duel, a lost family artifact, an unknown half-sibling, an ancestor's old enemy, or a parent's unfinished project. Resolutions create new echoes for the next generation.

### Worked example: the merchant's fall

| Gen | Heir | What happens | Legacy passed on |
|-----|------|--------------|------------------|
| 1 | Theron, merchant | Builds an empire with Thieves' Guild protection; refuses their price; dies poor | Guild debt on the bloodline |
| 2 | Elena, warrior | Rejects trade, becomes a knight, fights the guild, dies heroically | Legendary +50 warriors, -80 guild blood feud |
| 3 | Vera, warrior-born | Hunted from birth; chooses redemption, revenge, infiltration, or acceptance | Peace, a new cycle, a secret network, or normalized danger |

## Classes, Jobs, and Callings

Each character has three identity layers: a Class (what they can do in battle), a Job (how they make a living), and a Calling (what they believe in, unlocking faction abilities and quests). Example: a Spellblade who works as a Bounty Hunter with a Calling to the Storm God.

### Class families

| Family | Base class | Advanced classes |
|--------|-----------|------------------|
| Martial | Warrior | Knight, Berserker, Weaponmaster, Dragoon |
| Arcane | Mage | Elementalist, Chronomancer, Runesmith, Voidcaller |
| Divine | Acolyte | Paladin, Oracle, Inquisitor, Saint |
| Primal | Wildling | Druid, Shapeshifter, Beastmaster, Stormcaller |
| Shadow | Rogue | Assassin, Illusionist, Hexblade, Shadowdancer |
| Spirit | Medium | Necromancer, Summoner, Soulbinder, Ancestor-Speaker |
| Craft | Artisan | Artificer, Alchemist, Golemancer, Enchanter |

Heirs can switch classes during their life and keep abilities from mastered ones (Final Fantasy Tactics style). Mastering two base classes unlocks hybrids, e.g. Warrior + Mage = Spellblade.

### Era-locked classes

| Age | Exclusive classes |
|-----|------------------|
| Wild Magic | Dragon Rider, Primal Shaman, Beastcaller |
| Kingdoms | Templar, Court Mage, Warlord |
| Empire | Battle Mage, Legion Knight, Arcane Inquisitor |
| The Sundering | Riftwalker, Voidcaller, Plague Warden |
| Age of Ash | Scavenger, Ashen Monk, Wastes Ranger |
| Rediscovery | Ruin Delver, Lorekeeper, Relic Hunter |
| Arcane Industry | Magitech Engineer, Airship Captain, Golemancer |
| Final Age | Covenant-Breaker, Ascendant, Last Heir |

A bloodline that mastered an extinct class can trigger a rare Ancestral Revival event to bring it back in a later Age.

### Job families

| Family | Jobs |
|--------|------|
| Trade | Merchant, Smuggler, Caravan Master, Banker |
| Craft | Blacksmith, Enchanter, Alchemist, Runecarver, Tailor |
| Service | Healer, Innkeeper, Bard, Scribe |
| Law and Order | Guard, Bounty Hunter, Magistrate, Spy |
| Land | Farmer, Hunter, Beast Tamer, Miner |
| Arcane Work | Ley Surveyor, Curse-Breaker, Scroll Scribe, Familiar Breeder |

Job ranks: Apprentice, Journeyman, Master, Grandmaster. Ranking up takes in-game years.

### Family businesses

A job can become a family business (smithy, merchant house, academy, thieves' den) that grows while heirs run it and decays when abandoned. A business 200 generations old can become a world institution or a ruin a descendant stumbles into.

### Job effects in combat

| Job | Combat effect |
|-----|---------------|
| Blacksmith | Repair broken gear mid-battle |
| Alchemist | Potions 50% stronger; throw volatile mixtures |
| Bard | Party-wide buffs at turn start |
| Merchant | Bribe enemies to flee; extra loot |
| Beast Tamer | Recruit defeated monsters |
| Curse-Breaker | Remove debuffs; bonus damage to cursed enemies |
| Spy | See enemy stats and next moves |

## Skill Trees

Three tree layers separate what resets each life from what the family keeps forever.

| Tree | Resets? | Contents |
|------|---------|----------|
| Class tree | Each life | The class's abilities; branches toward advanced classes |
| Personal tree | Each life | Skills from job, calling, and life events (e.g. survived a dragon: fire resistance branch) |
| Bloodline tree | Never (all 999 generations) | Family meta-progression bought with Legacy Points |

### Legacy Points

Each generation earns Legacy Points from achievements. They buy permanent perks: stronger inherited stats, ancestral techniques, estate upgrades, and a family crest that buffs the party. Failed generations earn fewer points but can unlock unique scar branches available no other way.

### Node types

- **Active:** new abilities and spells
- **Passive:** stat boosts and resistances
- **Synergy:** bonuses with a specific job, trait, or second class
- **Keystone:** rare nodes that rewrite combat rules

### Keystones

| Keystone | Rule change |
|----------|-------------|
| Blood Magic | Spells cost HP instead of MP |
| Ancestral Echo | Every third turn, a random ancestor's signature technique fires |
| Glass Cannon | Double damage; die in one hit from criticals |
| Timeweaver | Once per battle, rewind the last full round |
| Wild Surge | Every spell gets a random bonus effect, good or bad |
| Iron Oath | No items; regenerate HP every turn |
| Soul Harvest | Defeated enemies' power temporarily becomes yours |
| Pack Leader | Summons and pets act twice; you act at half speed |
| Draconic Ascension | Dragonblood only: become a dragon for three turns |

Some keystones are bloodline-locked and only appear for families with a certain trait.

### Example: Elementalist tree

Core splits into Fire (Ignite, Phoenix), Frost (Freeze Turn, Glacier Wall), and Storm (Chain Lightning, Tempest Eye). All three branches converge on the keystone Elemental Convergence: cast two elements in one turn, and combo effects double.

## Combat

Battles use the classic Final Fantasy side-view layout, party on the right and enemies on the left, with front and back rows and class mechanics that change how each heir fights.

### Rows

- **Front row:** full melee damage dealt and taken
- **Back row:** reduced melee dealt and taken; ideal for mages and summoners
- **Knights** can guard the back row; **Rogues** can slip behind enemy lines

### Turn system

Either a classic Active Time Battle (ATB) gauge or a visible turn-order timeline (Final Fantasy X style). ATB feels most like classic FF; the timeline makes Shadow and Chronomancer turn manipulation easier to read.

**Open question:** ATB gauge or turn-order timeline?

### Class combat mechanics

| Class family | Unique mechanic |
|--------------|-----------------|
| Martial | Stances (offense, defense, counter); Rage meter builds from hits taken |
| Arcane | Spell-weaving: queue elements over turns and combine them (fire + wind = firestorm) |
| Divine | Oath meter: meet your oath's conditions to unlock miracles |
| Primal | Transformation into beast forms with their own skills |
| Shadow | Turn manipulation: delay enemies, steal initiative, strike from stealth |
| Spirit | Summons and ancestor spirits take party slots and act independently |
| Craft | Battlefield gadgets: turrets, traps, golems, mid-fight enchanting |

Hybrid classes merge mechanics at reduced strength: a Spellblade gets stances and spell-weaving; a Hexblade combines stealth with curses.

### Elemental surfaces

Spells change the battlefield per row: water conducts lightning, oil ignites, frost makes the row slippery, holy light damages undead standing in it. Flood the enemy front row, then strike it with lightning.

### Layered combat engine

Combat is computed from stacked layers, so two heirs fighting the same enemy play very differently.

1. Core rules: turn order, HP and MP, attack, defend, items
2. Class mechanic
3. Job tactic
4. Keystones
5. Traits: bloodline powers, curses, blessings
6. Gear abilities
7. Era effects: wild magic surges, ley strength, magitech

Example: a Berserker + Blacksmith with Blood Magic and a curse fights high-risk and aggressive; a Summoner + Beast Tamer with Pack Leader commands a monster army and barely attacks personally.

### Encounters

Enemies are visible on the map; no random encounters. Approach sets the opening: dropping onto an enemy from above gives a preemptive strike, being caught from behind is a back attack, and a Rogue ambush from a ledge earns a surprise round. Where the fight starts shapes the battlefield: near lava adds fire surfaces, a nearby family shrine buffs Divine magic.

### Legacy Arts

Ultimate moves charged over a battle, with cinematic animations. Heirs can unlock a famous ancestor's signature Legacy Art, so a Gen 300 heir might unleash a legendary Gen 12 swordmaster's technique.

## Story, Dialogue, and Party

The story blends a JRPG-style authored spine with CRPG-style reactivity: handcrafted Anchor Generations at key points, with procedural generations in between.

### Anchor vs. procedural generations

| Aspect | Anchor Generations | Procedural Generations |
|--------|-------------------|----------------------|
| When | The founding, the start of each Age, major catastrophes, the final generations | Everything in between |
| Feel | JRPG: cutscenes, set-piece battles, handcrafted dungeons | CRPG sandbox: open quests, reactive factions |
| Built from | Authored content that adapts to family history | Trait, failure, reputation, and legacy echo systems |

Anchor chapters adapt to history: the founding of the Empire plays very differently for a bloodline of outlaws than one of nobles.

### Trait-gated dialogue

Dialogue options unlock from bloodline, class, job, reputation, and stats, so the same conversation differs every generation. Examples:

- [Faetouched] See through a glamour
- [Blacksmith Master] Spot a forged blade
- [Dragonblood] Speak to a dragon in its own tongue
- [Thieves' Guild -60] The guild comes to collect
- [Intelligence 15] Notice a contradiction in a noble's story

### Party

The active party is the current heir plus up to three companions.

| Companion type | Source | Behavior |
|----------------|--------|----------|
| Family members | Siblings, spouse, children, long-lived relatives | Procedural, with JRPG-style personal quests and banter |
| Recruited allies | Mercenaries, monsters, wanderers | CRPG approval system; can leave or betray you |
| Legendary companions | Authored characters: an immortal fae, a sentient sword, a dragon | Appear across many generations; the main cast tying 999 generations together |

A companion who knew your great-grandfather and judges you by his standard is a key source of humor and heartbreak.

## World and Building

Exploration is 2D side-view with full Terraria-style freedom: dig anywhere, build anything, and everything persists across generations.

### Vertical layers

| Layer | Contents |
|-------|----------|
| Sky | Floating islands, cloud cities, dragon roosts, celestial temples |
| Surface | Towns, forests, kingdoms, the family estate |
| Underground | Caves, mines, dwarven halls, buried ruins |
| The Deep | Ley veins, ancient horrors, Ancient Vaults |

Digging down means going back in time. Each Age builds on top of the last, so digging deeper reaches older history. A Gen 700 heir might dig through Empire ruins, then a Kingdoms-era castle, and finally reach the founder's Gen 1 home, with lost heirlooms, journals, and ghosts.

### The Strata system

At every Age transition, the world runs a batch simulation:

1. **Decay:** structures weaken based on maintenance
2. **Burial:** sediment, ash, sand, or rubble cover the old surface
3. **Reclamation:** nature, monsters, or other peoples move into ruins
4. **New surface:** fresh terrain, towns, and kingdoms form on top

The world can't grow downward forever, so the oldest layers compress into the Deep: most material becomes rock and rare ore, while meaningful structures survive as preserved Ancient Vaults (founder's home, legendary tombs, heirloom rooms, Covenant sites).

### Structure decay between generations

| Maintenance | Result |
|-------------|--------|
| Actively maintained | Survives intact |
| Lightly maintained | Minor damage, still usable |
| Abandoned | Ruined, overgrown, possibly monster-infested |
| Abandoned many generations | Buried; becomes a dungeon |
| Lost in a failure | Destroyed or taken by enemies |

### Class and job shape building

| Identity | Building or digging ability |
|----------|---------------------------|
| Earth Mage | Reshape terrain, raise walls, carve tunnels instantly |
| Stonekin heritage | Mine faster, sense ore through rock |
| Fire Mage | Burn through obstacles, smelt without a forge |
| Golemancer | Automated mining and building golems |
| Druid | Grow trees, vines, and living structures |
| Riftwalker | Place portals between distant points |
| Miner (job) | Bonus ore yield, rare gems |

### Magical blocks

Ward stones, ley conduits, rune doors (open only for your bloodline), teleport circles, enchanted walls, shrines, and ancestor altars (commune with past heirs, unlock ancestral techniques).

### Estate and NPC housing

NPCs move into proper housing, including your own family: siblings, children, aging parents, long-lived relatives. Specialized rooms (library, forge, temple) attract NPCs with matching jobs. The estate persists across generations and can be lost in a failure and reclaimed later.

### Sieges

Every few generations, dragon raids, rival houses, monster surges, or undead armies test your defenses. Walls, wards, traps, and golems weaken enemy waves; breakthroughs play out on the side-view battle screen. Losing a siege can trigger a failure.

### Protecting story sites

- **Sealed sites:** story locations and boss arenas are warded until the story unlocks them
- **Reactive story:** breaking in early changes the outcome (waking the dragon too soon can trigger a failure)
- **Anchor zones:** authored regions the Strata system never destroys

## Multiple Worlds and Teleportation

The family can expand across nine realms linked by teleport systems, each a full dig-and-build world with its own resources, dangers, and flow of time.

### The realms

| World | Feel | Unique resources | Danger |
|-------|------|-----------------|--------|
| Material Realm | Home; all eight Ages play out here | Common ores, farmland, kingdoms | Moderate |
| Verdant Court | Fae realm of enchanted forests | Fae silk, glamour crystals, moonwood | Contracts and trickery |
| Hollow Below | Realm of the dead | Soul gems, grave iron, ancestral relics | Undead, death debts |
| Celestial Spires | Divine realm in the clouds | Starmetal, holy light essence | Judgment of the gods |
| Elemental Planes | Four worlds: fire, frost, storm, earth | Pure elemental cores | Extreme environments |
| Dragon Isles | Floating sky archipelago | Dragonbone, scales, sky ore | Dragons rule |
| Dreamlands | Self-reshaping world | Dream essence, memory shards | Nightmares, sanity loss |
| The Void | Appears after the Sundering | Voidglass, rift crystals | Reality breaks down |
| Clockwork Expanse | Unlocks in Arcane Industry | Aetherium, gears, golem cores | Rogue constructs |

### The Hollow Below

Every heir you have played ends up here after death, and you can visit them. Depending on how they lived and died, ancestors offer wisdom or techniques, suffer curses you can break, or resent choices you made while playing their child.

### Teleport tiers

| Tier | Range | Notes |
|------|-------|-------|
| Waystones | Within one world | Found or built; cheap |
| Family Teleport Circles | Any family circle, any world | Player-built at estates; powered by ley conduits; a private network over generations |
| World Gates | Between realms | Ancient, mostly dormant or buried; repairing them is a major quest line |
| Rifts | Random | Post-Sundering, free but unstable; raises the Fate roll on entry |
| Personal planar travel | Class or trait based | Riftwalkers tear portals; Faetouched use mushroom rings; Necromancers descend to the Hollow |
| Airships | Sky realms | Arcane Industry Age |

Some gates are bloodline-locked: a gate sealed by the founder may open only for their descendants.

### Gates across the Ages

| Age | Gate status |
|-----|------------|
| Wild Magic | Gates open naturally |
| Empire | Gates controlled; travel requires permits |
| The Sundering | Most gates shatter; rifts everywhere |
| Age of Ash | Worlds isolated; other realms become legends |
| Rediscovery | Gates dug up and repaired |
| Arcane Industry | Magitech gates and airships make travel routine |

A family that preserved a working gate through the Sundering holds enormous power in the Age of Ash.

### Time dilation

| World | Time vs. home |
|-------|--------------|
| Verdant Court | 1 day there = 1 year home |
| Celestial Spires | 1 month there = 10 years home |
| Hollow Below | Time barely passes |
| Dreamlands | Random |
| The Void | May flow backward |

An heir who stays too long in another realm can trigger a generation transition; play moves to the next heir, and the lost one may return generations later as a young NPC, an ancestor younger than their descendants. Careful heirs can also exploit dilation: train for years in the Spires, or wait out a war in the Hollow.

### Cross-world properties

Families can claim land in multiple realms (estate at home, trading post in the Verdant Court, forge on the Fire Plane, tomb in the Hollow). All properties follow the same maintenance and decay rules, and rivals or monsters can claim neglected ones.

## High-Magic Setting

Magic is everywhere: seven sources, twelve schools, nine peoples, and creatures and gear that persist across generations.

### Sources of magic

| Source | How it works | Risk |
|--------|-------------|------|
| Leylines | Draw on the world's energy veins | Weak where leylines are damaged |
| Bloodline | Inherited power | Fades as the line dilutes |
| Divine | Granted by gods | Revoked if faith breaks |
| Pact | Borrowed from entities | Debts come due |
| Fae / Wild | Chaotic, emotional magic | Unpredictable |
| Soul | Your own life force | Shortens lifespan |
| Runic | Inscribed, learned, stable | Slow to prepare |

Ley Strength shifts by Age (overwhelming in Wild Magic, broken after the Sundering, industrialized later), so the same spell's power depends on when it is cast.

### Schools

Fire, Frost, Storm, Earth, Light, Shadow, Life, Death, Time, Space, Mind, Void. Some are era-restricted: Necromancy is outlawed under the Empire; Void is unknown before the Sundering.

### Peoples

| People | Lifespan | Hook |
|--------|----------|------|
| Humans | ~70 years | Adaptable; fastest generations |
| Highborn Elves | ~800 years | Can outlive 30+ of your generations |
| Stonekin | ~300 years | Master crafters; century-long grudges |
| Fae | Ageless | Contracts, glamour, trickery |
| Dragonkin | ~500 years | Draconic magic, pride |
| Beastfolk | ~60 years | Primal power, tribal clans |
| Undying | Endless | Former mortals, often former ancestors |
| Celestials | Ageless | Divine messengers; rare |
| Golemborn | Unknown | Artificial people of the Arcane Industry Age |

Mixed marriages add heritage traits that can resurface hundreds of generations later. Long-lived relatives recur: an elven spouse from Gen 40 may still be alive at Gen 70 as the family's living memory.

### Creatures

| Tier | Examples |
|------|----------|
| Common | Slimes, wolves, imps, sprites |
| Elite | Griffins, basilisks, wraiths, treants |
| Legendary | Dragons, krakens, phoenixes, titans |
| Mythic | World-serpents, fallen gods, the Covenant entity |

Long-lived creatures are generational NPCs: a dragon lives ~1,000 years (about 40 generations) and remembers what your ancestors did. Bonded familiars and mounts can be inherited, gaining power and memories with each heir. Creature populations shift by Age: wild beasts early, rift-spawn after the Sundering, constructs in the industrial era.

### Weapons and armor

| Tier | Material | Property |
|------|----------|----------|
| 1 | Iron and Steel | Baseline |
| 2 | Silversteel | Anti-undead, anti-fae |
| 3 | Mithral | Light, magic-conductive |
| 4 | Dragonbone | Elemental affinity |
| 5 | Starmetal | Fallen from the sky; rare |
| 6 | Voidglass | Post-Sundering; unstable |
| 7 | Aetherium | Endgame; nearly divine |

Rarity runs Common, Uncommon, Rare, Epic, Legendary, Mythic, Ancestral. Enchanters inscribe runes into gear slots (elemental damage, lifesteal, resistances, on-hit curses); higher job rank means more slots. Armor sets forged by the same ancestor grant family set bonuses.

### Heirlooms and sentient weapons

Heirlooms gain experience from every heir who uses them, unlock abilities tied to specific ancestors, and can awaken into sentient legendary weapons. They can be lost, stolen, or shattered in failures and recovered centuries later. Sentient weapons have personalities and opinions; one that hated your grandfather may refuse to work until you earn its trust.

## Technical Architecture and Claude Code Handoff

Build in Godot 4 with game logic fully separated from rendering and all content in data files, so the 2D side-view game can later be reskinned as isometric 3D.

### Core principles

- **Logic separate from visuals:** battle, traits, Fate, reputation, and simulation run without knowing how they are drawn.
- **Data-driven content:** traits, classes, jobs, keystones, monsters, items, and realms live in JSON; code reads data, never hardcodes it.
- **Deterministic simulation:** seeded random number generation so generations and Age transitions are reproducible and testable.
- **Engine:** Godot 4 (strong 2D TileMap tools, solid 3D, free; GDScript reads like Python). Unity is the alternative.

### Suggested repo layout

```
/docs/GDD.md            this document, exported as Markdown
/data/traits/*.json     trait definitions
/data/classes/*.json    classes, advanced and era-locked
/data/jobs/*.json
/data/keystones/*.json
/data/items/*.json
/data/creatures/*.json
/data/realms/*.json     realms, time multipliers, resources
/core/lineage/          family tree, inheritance, mutation
/core/fate/             Fate Value, milestone checks, severity
/core/memory/           legacy echoes, reputation, factions
/core/battle/           layered combat engine (no rendering)
/core/sim/              Age transitions, decay, strata
/world/                 tile world, chunks, building, digging
/ui/                    battle screen, menus, family tree view
/tests/                 unit tests for core systems
```

### Example data record

```json
{
  "id": "mageblood",
  "category": "bloodline",
  "inherit_chance": 0.60,
  "dormant_chance": 0.0,
  "effects": [{"stat": "element_power", "value": 0.20}],
  "mutations": ["ice_mage", "wild_mage", "burnt_out"],
  "conflicts": ["magically_burned"],
  "fate_modifier": 0.0
}
```

### Save and world system

- Each realm is its own save: a seed plus a change log of player edits, split into chunks that load independently.
- The gate and teleport network is stored as a graph of linked nodes.
- Each realm keeps its own clock with a multiplier relative to the Material Realm; on return, elapsed home time triggers decay.
- Age transitions run as batch jobs during a loading screen; compressed strata keep only their Ancient Vaults.
- Unvisited realms get a lightweight summary simulation instead of tile-by-tile updates.
- The family tree and legacy echoes are a separate persistent save shared across all realms.

### Build roadmap

1. **Lineage core:** family tree, trait inheritance and mutation, Fate rolls; test with a text-only simulation of 999 generations.
2. **Battle prototype:** side-view rows, turn system, two class families, a few keystones.
3. **Tile world:** one realm, side-view dig and build, chunked saves.
4. **Generation loop:** play a life, pass to an heir, NPC parent, estate persistence.
5. **World memory:** legacy echoes, factions, reputation-driven quests.
6. **First Age vertical slice:** Age of Wild Magic, one Anchor Generation, failures and sieges.
7. **Strata and Age transitions:** decay, burial, Ancient Vaults.
8. **Second realm and teleportation:** Hollow Below, family circles, time dilation.
9. **Expand content:** remaining classes, jobs, realms, and Ages.

## Using this with Claude Code

Export this doc as Markdown into `/docs/GDD.md`, and add a short CLAUDE.md at the repo root pointing to it, stating the engine, the logic-versus-rendering rule, and the current roadmap phase. Work one roadmap phase at a time so each system is built and tested before the next depends on it.
