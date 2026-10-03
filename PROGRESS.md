# Generational Legacy RPG — Development Progress

**Status:** Phase 5 (Rendering & UI Layer) in progress. **Core engine complete, dialogue and consequence systems added, romance/marriage complete, UI foundations built.**

**Test Coverage:** 128 tests covering all systems (Lineage, Fate, Combat, World, Generation Loop, UI Screens, Dialogue, Consequences, Romance).

---

## Phase 1: Lineage Core ✅ COMPLETE

### Systems Built
- **Lineage** (family tree, inheritance, heir creation)
- **Heir** (character class with stats, traits, relationships)
- **Fate** (failure rolls, milestone checks, severity, archetypes)
- **Trait System** (30 traits with mutations, conflicts, inheritance)
- **TraitLoader** (JSON-based content loading)

### Features
- 999-generation family tree simulation
- Trait inheritance with probability (40-100% depending on trait)
- Trait mutations (15% chance)
- Dormant traits skip generations
- Fate Values (1-30% lifetime failure chance)
- 5 milestone checks per life
- 6 heir archetypes (Restorer, Rebel, Inheritor, Survivor, Redeemer, Successor)
- Trait conflicts create friction rather than cancel

### Data
- 10 bloodline traits
- 5 acquired traits
- 5 curse traits
- 5 blessing traits
- All traits include effects, mutations, inheritance rules

### Tests (8 tests)
✓ Founder creation
✓ Heir production from parents
✓ Trait inheritance probability
✓ Trait mutations
✓ Fate Value rolling and tiers
✓ Milestone checks
✓ 999-generation simulation
✓ Fate modifier integration

---

## Phase 2: Combat System ✅ COMPLETE

### Systems Built
- **Battle** (turn-based combat engine)
- **Combatant** (character in combat with actions and effects)
- **Damage System** (row-based positioning, trait modifiers, job effects)
- **Class Mechanics** (stances, rage meter, spell-weaving, oath meter, beast forms)
- **Action System** (attack, defend, cast spell, use item, stance)
- **Turn Order** (calculated by dexterity)

### Features
- Front/back row positioning with modifier effects
- Damage calculation with stacking modifiers:
  - Base (strength × 2)
  - Defense (constitution)
  - Row bonus (back row +5 def)
  - Trait modifiers (Warrior's Steel +30%, Mageblood +20%, etc.)
  - Job modifiers (Blacksmith +10% damage)
  - Critical hits (5% + dexterity bonus)
- Class-specific mechanics:
  - **Martial:** Rage meter (fills from hits taken)
  - **Arcane:** Spell queue (combine elements over turns)
  - **Divine:** Oath meter (fill on beneficial actions)
  - **Primal:** Beast forms with unique skills
  - **Shadow:** Turn manipulation and stealth
  - **Spirit:** Summons take party slots
  - **Craft:** Battlefield gadgets (turrets, traps, golems)
- Buff/debuff system
- Elemental surfaces (water conducts lightning, oil ignites, etc.)
- Valid action filtering (limited by MP, rage meter, etc.)
- Battle end conditions (all enemies dead = win, all party dead = loss)

### Tests (13 tests)
✓ Combatant creation
✓ Damage calculation
✓ Back row defense bonus
✓ Trait damage modifiers
✓ Battle initialization
✓ Turn order by dexterity
✓ Attack action execution
✓ Dead combatant restriction
✓ Stance changes buffs
✓ Valid actions based on resources
✓ Rage meter buildup
✓ Battle end condition
✓ Full round simulation

---

## Phase 3: World System ✅ COMPLETE

### Systems Built
- **Realm** (individual world with chunks, resources, creatures)
- **Chunk** (16×16 tile area with structures, entities, decay)
- **WorldManager** (multi-realm system, teleportation, properties)

### Features: 9 Interconnected Worlds

| Realm | Time Multiplier | Resources | Danger | Access |
|-------|-----------------|-----------|--------|--------|
| Material (Home) | 1× | Iron, copper, wheat | Medium | None |
| Verdant Court | 365× (1 day = 1 year) | Fae silk, glamour crystal, moonwood | High | Faetouched |
| Hollow Below | 0.01× (slow time) | Soul gem, grave iron, ancestral relic | Very High | Marked by Death |
| Celestial Spires | 120× (1 month = 10 years) | Starmetal, holy essence | Very High | Divine Favor |
| Elemental Planes (4) | 2× | Elemental cores, essence | Extreme | None |
| Dragon Isles | 1.5× | Dragonbone, dragon scale, sky ore | Extreme | Dragonblood |
| Dreamlands | Random | Dream essence, memory shards | Medium | None |
| The Void | -1× (backward) | Voidglass, rift crystals | Extreme | Post-Sundering |
| Clockwork Expanse | 1.2× | Aetherium, gears, golem cores | High | Arcane Industry |

### World Features
- **Chunk System:**
  - 16×16 tile chunks (procedurally generated)
  - ~1.6 million chunks per realm (sparse loading)
  - Layer-based generation:
    - Surface (z=0): grass, forest, water, mountains
    - Underground (z<20): stone, ore, caves
    - Deep (z>20): ancient ruins, ley veins, rare artifacts
  - Procedural generation with seeding (reproducible)
  - Structure support (buildings, shrines, magical items)
  - Entity support (NPCs, creatures, wildlife)

- **Persistence:**
  - Chunk maintenance level (0-100)
  - Decay over generations (20+ gens = major damage)
  - Player can claim properties (estates, businesses, tombs, trading posts)
  - Family properties persist across generations
  - Chunk unloading to save memory

- **Exploration:**
  - Movement in 3D (x, y, z = horizontal + depth)
  - Digging down (z increase = going back in time)
  - Dig deep enough to find founder's home, ancestor tombs, Ancient Vaults
  - Build structures (houses, smithies, shrines)

- **Teleportation:**
  - Waystone network (fast travel points)
  - Gate system (connect two realms)
  - Bloodline-locked gates (only descendants can use)
  - Time dilation affects player (spend 1 day in Spires, 10 years pass at home)

- **Resources:**
  - Unique per realm (fae silk only in Verdant, aetherium only in Clockwork)
  - Rarity tiers: common → rare → ancestral
  - Used for crafting, enchanting, heirlooms

### Tests (18 tests)
✓ All 9 realms initialized
✓ Realm properties and time multipliers
✓ Chunk generation and retrieval
✓ Procedural generation (deterministic)
✓ Layer-based terrain variation
✓ Teleportation between realms
✓ Player movement
✓ Digging down
✓ Building structures
✓ Claiming properties
✓ Property filtering by realm
✓ Time dilation calculation
✓ Trait-gated access restrictions
✓ Access with correct traits
✓ Waystone network
✓ World summary
✓ Chunk decay over generations
✓ Multiple chunk loading
✓ Chunk unloading

---

## Test Summary

| Phase | Module | Tests | Status |
|-------|--------|-------|--------|
| 1 | Lineage | 6 | ✅ Pass |
| 1 | Integration (Lineage + Fate) | 2 | ✅ Pass |
| 2 | Battle | 13 | ✅ Pass |
| 3 | World | 18 | ✅ Pass |
| 4 | Generation Loop | 20 | ✅ Pass |
| 5 | UI Screens | 12 | ✅ Pass |
| 5 | Event System | 15 | ✅ Pass |
| 5 | Character UI | 17 | ✅ Pass |
| 5 | Dialogue & Quest Screens | 16 | ✅ Pass |
| 5 | Consequence Notifications | 3 | ✅ Pass |
| 5 | Romance & Marriage | 6 | ✅ Pass |
| **TOTAL** | | **128** | ✅ **PASS** |

---

## Phase 4: Generation Loop & NPC Parents ✅ COMPLETE

### Systems Built
- **GenerationManager** (one heir's full life cycle)
- **NPCSystem** (old heirs as NPCs and legendary companions)
- **ReputationSystem** (faction standing and legacy echoes)
- **EstateManager** (family properties with decay and upgrades)

### Features: Complete Life Cycle

**Life Phases:**
- Childhood (0-12): Learning from parents, gaining foundation skills
- Adolescence (13-17): First quests, finding identity, choosing class/job
- Adulthood (18-50): Main story arc, building legacy, business/romance
- Elderhood (51-64): Mentoring next generation, consolidating achievements
- Death (65+): Natural death, becomes ancestor NPC

**Natural Life Events:**
- Marriage: 5% chance per year in adulthood
- Children: 10% chance per year after marriage
- Quests: Generated from legacy echoes and factions
- Mentoring: Elderhood teaches wisdom to next heir
- Natural death: Guaranteed at 65+

**NPC Ancestor System:**
- Retired heirs become NPCs with personality (from traits)
- Wisdom level determines advice quality
- Legendary companions (exceptional ancestors) persist across generations
- Tombs in Hollow Below (Realm of the Dead)
- Visit ancestors to learn signature techniques (Legacy Arts)
- Ancestors judge heir's actions (approval affects quests)

**Reputation & Legacy:**
- 9 factions with -100 to +100 standing per bloodline
- Legacy echoes (memorable ancestor actions) persist 100+ generations
- Memory tiers: Personal (3 gen) → History (20 gen) → Legend (100 gen) → Myth (100+)
- Failure consequences: betrayals, curses, defeats hurt specific factions
- Success consequences: heroic deeds, alliances, discoveries help factions
- Child inherits 50% of parent's faction reputation
- Factions affect quest availability and NPC treatment

**Estate & Property System:**
- 6 property types: Estate, Smithy, Library, Trading Post, Tomb, Shrine
- Annual upkeep and income based on type
- Maintenance level (0-100) determines functionality
- Decay over generations: -10 per 5 gens unattended, -15 per 20 gens
- 4 upgrade types per property: Forge, Library, Barracks, Market
- Upgrades increase annual income
- Property efficiency affects crafting/learning bonuses
- Can reclaim ruined properties (restore to 50%)
- Cross-realm properties (estates in Verdant Court, tombs in Hollow, etc.)

### Tests (20 tests)
✓ Life phase progression (childhood → elderhood)
✓ Marriage and children (natural generation)
✓ Trait inheritance from both parents
✓ Natural death at age 65
✓ Generation transition (heir selection, old heir becomes NPC)
✓ Ancestor NPC creation with personality
✓ Visit ancestral tomb
✓ Learn from ancestor's wisdom
✓ Faction reputation changes
✓ Legacy echo creation
✓ Memory decay over generations
✓ Reputation inheritance (50% from parent)
✓ Quest execution with faction consequences
✓ Estate property creation
✓ Property decay and maintenance
✓ Property upgrades
✓ Annual property income
✓ Condition descriptions
✓ Life summary generation
✓ Ancestry tracking and summary

### Tests (20 tests)
✓ Life phase progression
✓ Marriage and children
✓ Natural death at 65
✓ Generation transition
✓ Ancestor NPC creation
✓ Visit ancestral tomb
✓ Learn from ancestor
✓ Faction reputation changes
✓ Legacy echo creation
✓ Memory decay
✓ Reputation inheritance
✓ Quest execution
✓ Estate property creation
✓ Property decay
✓ Property upgrades
✓ Annual property income
✓ Condition descriptions
✓ Life summary generation
✓ Ancestry tracking and summary
✓ Comprehensive generation lifecycle

---

## Phase 5: Rendering & UI Layer 🎮 IN PROGRESS

### Systems Built (Foundations)
- **MainGame** (game state orchestrator and screen manager)
- **ScreenManager** (CanvasLayer for UI layering)
- **MainMenuScreen** (new game, load, quit)
- **WorldScreen** (tile-based exploration, movement, digging)
- **BattleScreen** (combat UI with turn order, HP bars, actions)
- **CharacterMenuScreen** (character sheet, inventory, equipment, traits)
- **CharacterMenuEnhanced** (tabbed interface with skills, family, inventory)
- **PauseMenuScreen** (pause/resume, save/load, return to menu)
- **GenerationTransitionScreen** (life summary, heir selection, mentor choice)
- **LoadGameScreen** (save slot browser)
- **DialogueTreeScreen** (interactive NPC conversations with branching choices)
- **QuestDetailScreen** (quest information display with rewards and difficulty)
- **ConsequenceNotificationScreen** (outcome display with visual feedback)
- **DialogueSystem** (7 dialogue trees: 3 quests, 2 NPCs, 2 romance/marriage)

### Features: Phase 5 Foundations
- Screen transition system with state persistence
- Main menu with new game/load/quit
- World exploration with keyboard movement (WASD)
- Digging system (D key to go down levels)
- Character sheet with stats, traits, inventory display
- Pause menu with save/load options
- Generation transition with heir selection from children
- Ancestor mentor selection
- Save game serialization to JSON
- Load game from save slots

### Features: Year-by-Year Progression
- EventSystem generates 9 types of events (quest, marriage, romance, betrayal, success, rival, inheritance, discovery)
- YearActionScreen shows current heir, age, phase, and available actions
- Life progress bar (0-65 years)
- Weighted random event generation (quests 30%, romance 20%, success 15%, etc.)
- Phase-appropriate events (childhood, adolescence, adulthood, elderhood)
- Event consequences system (wealth, reputation, trait changes)
- Event acceptance/decline/ignore options
- EventPopupScreen displays event details with player choices

### Features: Character UI Enhancement
- SkillTree component with class-specific progression trees
- Skill nodes with prerequisites, levels (1-3), and descriptions
- Learn and upgrade mechanics with prerequisite checking
- Warrior skills: Slash, Whirlwind, Shield Bash, Last Stand
- Mage skills: Fireball, Inferno, Frost Nova, Meteor
- Rogue skills: Backstab, Shadow Clone, Poison Strike, Deathmark
- FamilyTreeBrowser component with ancestor browsing
- Tabbed character menu (Character, Skills, Family, Inventory)
- Integrated skill tree visualization in menu
- Integrated family tree in menu
- Ancestry line tracking and descendant lookup

### Tests (12 + 15 + 17 = 44 tests)
✓ Main game initialization
✓ New game starts world screen
✓ Character menu opens from world
✓ Pause menu toggles
✓ Battle screen initialization
✓ World screen player position tracking
✓ Character menu displays heir stats
✓ Generation transition shows children
✓ Save game file creation
✓ Screen transitions preserve state
✓ Pause/resume preserves player position
✓ All screens properly instantiate

### Estimated Scope Completed
- 10-15 hours of UI foundation
- 6 core screens with basic layouts
- 1,000+ lines of UI code
- Screen manager infrastructure

### Phase 5 Completed
✅ Screen management infrastructure
✅ Main menu, world, battle, character menus
✅ Pause menu with save/load
✅ Generation transition with heir selection
✅ Save/load system
✅ Year-by-year progression system
✅ Event system (9 event types)
✅ Event popups with choices
✅ Skill trees (class-specific)
✅ Family tree browser
✅ Enhanced character menu with tabs
✅ Dialogue tree system with branching conversations
✅ Interactive dialogue screen with player choices
✅ Quest detail screen with rewards preview
✅ Dialogue outcome application (gold, reputation, quests)
✅ Consequence notification system with visual feedback
✅ Color-coded outcome display (gold, reputation, quests, items)
✅ Romance encounter dialogue (3 choice branches)
✅ Marriage proposal dialogue (3 choice branches)
✅ Romance interest and marriage tracking

### Phase 5 Remaining Work

1. **Battle Screen Integration** (5-8 hours)
   - Connect to actual Battle system
   - Implement turn order visual (ATB gauge or timeline)
   - Add HP/MP bar animations
   - Floating damage numbers (with crit colors)
   - Ability buttons with proper action binding
   - Status effect icon display
   - Row positioning visualization

2. **World Rendering Enhancement** (8-12 hours)
   - Real tilemap display with tile graphics
   - Player sprite and movement animations
   - Building/structure tile sets
   - Creature and NPC sprite rendering
   - Weather particle effects
   - Portal/teleport point visualization
   - Chunk loading/unloading indicators

3. **Generation Transition Enhancement** (2-3 hours)
   - Full life summary statistics
   - Heir stat preview before selection
   - Mentor bonus preview and selection UI
   - Legacy echo display (ancestor deeds)

4. **Event Enhancements** ✅ (COMPLETE)
   - ✅ Interactive dialogue tree display
   - ✅ Quest detail screens with rewards preview
   - ✅ Player choice branching system
   - ✅ Consequence notifications and visual feedback
   - ✅ Romance encounter dialogue (3 branches)
   - ✅ Marriage proposal dialogue (3 branches)

5. **Animations & Polish** (5-10 hours)
   - Screen transition animations (fade, slide)
   - Button hover effects and highlights
   - Smooth scrolling and transitions
   - Audio/SFX integration points
   - Responsive UI scaling for different resolutions

### Estimated Total Remaining
- 15-25 hours (polish and battle/world integration, no dialogue work)
- 1,500+ lines of additional rendering code
- Full integration with core combat and exploration
- Professional UI/UX refinements and animations

### Estimated Work Completed
- 15-20 hours (dialogue systems, consequences, romance/marriage)
- 1,000+ lines of dialogue and UI code
- Event system fully integrated with visual feedback
- All dialogue trees implemented and tested

**Core game logic: COMPLETE ✅**
- All systems work standalone
- All systems tested and verified
- Ready to wire up to UI

---

## Architecture Scorecard

| Principle | Status |
|-----------|--------|
| **Logic before rendering** | ✅ All combat and world logic runs independently |
| **Data-driven content** | ✅ 30 traits + realm/chunk generation in JSON |
| **Deterministic simulation** | ✅ Seeded RNG for reproducible games |
| **Modular systems** | ✅ Lineage, Fate, Battle, World each testable alone |
| **Composable** | ✅ All systems integrate through clear interfaces |
| **Scalable to 999 gens** | ✅ Tested with 999-generation simulation |
| **Memory efficient** | ✅ Chunks load/unload, properties are sparse |

---

## Code Statistics

| Category | Count |
|----------|-------|
| Core systems | 13 classes (Lineage, Heir, TraitLoader, FateSystem, Battle, Realm, Chunk, WorldManager, GenerationManager, NPCSystem, ReputationSystem, EstateManager, EventSystem) |
| UI screens | 12 screens (MainMenu, World, Battle, Character, Pause, GenerationTransition, LoadGame, YearAction, EventPopup, DialogueTree, QuestDetail, ConsequenceNotification) |
| UI components | 2 components (SkillTree, FamilyTreeBrowser) + ScreenManager + CharacterMenuEnhanced |
| Dialogue systems | DialogueSystem with 7 dialogue trees (3 quests, 2 NPCs, 2 romance/marriage) |
| Dialogue features | Branching conversations, outcome application, consequence tracking |
| Data files | 4 JSON files (30 traits across 4 categories) |
| Tests | 128 tests across 11 modules (all passing) |
| Lines of code | ~8,200 (logic + UI + components + dialogue + consequences + romance) |
| Commits | 20 major commits showing progression |
| Documentation | GDD (25k words), CLAUDE.md, README, TESTING.md, PROGRESS.md |
| Modules | Phase 1-4 complete, Phase 5 in progress (UI, Events, Character Systems, Dialogue complete) |

---

## Performance Notes

- Lineage: Simulates 999 generations in <1 second
- Chunks: Sparse loading (only loaded chunks in memory)
- Battle: One round simulates instantly (no rendering overhead)
- World: 9 realms × ~1.6M chunks each (on-demand generation)

---

## Known Limitations (Future Work)

**Phase 4 blockers:**
- No UI rendering
- No actual generation transition (still manual)
- No NPC parent interaction

**Future phases:**
- Multiplayer/co-op
- Mobile version
- Mod support
- Advanced AI for NPC parents
- Dynamic marriage/children system

---

## Quick Start

```bash
cd /home/user/GenerationalLegacyRPG

# Run all tests
godot --headless -s res://addons/gut/gut_cmdline.gd -gtest=res://tests/

# Read the design
cat docs/GDD.md

# See architecture
cat CLAUDE.md
```

---

**Last Updated:** Oct 3, 2026
**Next Milestone:** Phase 4 (Generation Loop) — ~1 week
