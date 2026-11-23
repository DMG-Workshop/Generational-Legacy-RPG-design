# Shop services: enchanting, spellcasting, and opening hours

Design for two paid **services** a shop does *for* the heir (as opposed to selling a thing off a shelf), and for the life screen's **Shops** button keeping
shop hours. Status: **opening hours, enchanting and spellcasting are all built and tested** (below).

A service is already a concept: a shop's `services` list in `data/shops/shops.json` (the bathhouse's hot bath) is run by `GameShops.serve(d, shop, service_id)`:
a price (`GameShops.service_price`: the town's prices and the heir's haggling count), an effect (`heal`, `mp` shares), a line of text, no dice, no time.
The two new services use the same row, the same panel (`ui/play/shop_panel.gd` `_build_shop`) and the same price path.

## 3. Opening hours (built)

**The rule.** Every shop of shops.json has `hours: [open, close]` on the 24-hour day (`GameDay.hour(d)`, 0-24; the open world's `world_seconds`). It is open
from `open` up to **but not including** `close`. The six old services (forge, store, temple, tavern, board, black market) have no hours and are always open;
`GameShops.is_shop(id)` separates them.

| Piece | Where | What it does |
|---|---|---|
| `GameShops.is_open(d, id)` / `open_at(id, hour)` | `game_shops.gd` | The test (unchanged). |
| `GameShops.shut_line(d, id)` | `game_shops.gd` | `""` while open; else "X is shut. It opens at 08:00 and closes at 18:00." (`text.not_open`). |
| `GameShops.closing_soon(d, id)` | `game_shops.gd` | `""` or "X closes at 18:00." in the last `settings.last_call_hours` (1.0) before closing. |
| `GameShops.open_here(d)` | `game_shops.gd` | The shops of this town that are open now. |
| `_buy`, `sell`, `sell_material`, `serve` | `game_shops.gd` | Refuse with `shut_line` before touching gold, stock, pack or stores. |
| Life screen **Shops** button | `ui/play/life_screen.gd` | Stays enabled (the forge, store and temple never close); its tooltip lists the shops shut now and when each opens. |
| Shop panel tab of a shut shop | `ui/play/shop_panel.gd` `_build_shop` | Shows "Shut until 08:00 (open 08:00 to 18:00)." and nothing to buy or sell; a shop in its last hour shows the closing line above the shelf. |
| The keeper in the open world | `GamePeople.talk`, `GameVillagers.present` | Already gone / silent when shut (unchanged). |

**Closed vs open states.** Two states and a warning: *open*, *closing soon* (last hour, trade still allowed), *shut*. There is **no grace after closing**:
a purchase at 18:00 is refused. A heir who is mid-way through a purchase when the hour ticks over (the open world's clock runs while the panel is not open,
the world waits while a `modal` panel is open) is not affected: the panel is a snapshot of the hour it opened at, and a *new* action re-reads the hour.

**Day-of-week.** The game has no weekday: its calendar is the year and the four seasons (`GameWorld`), and the day is an abstract rhythm
(`GameDay`, `day_seconds` 150). So hours are the only time-of-day check, and the season does not shut a shop. If weekdays or holidays are added, the
hook is a `closed_days` list on a shop read by `is_open`; nothing here assumes one.

**The life screen's clock.** Nothing in the text game feeds the world clock, so on the life screen the hour stays where it was (a new house starts at
`start_phase` 0.3, about 07:12). Shops opening at 08:00 or later (`id`s with `hours` 8-19, 9-17, 10-20 and so on: the jeweller, scribe, bank, guild hall...)
therefore read as shut on the life screen until the player has walked the open world long enough for the day to pass. That is intended (it makes the
hour matter), but if it reads as a bug in play, the fix is a `settings.life_screen_hours` switch (off: the life screen ignores hours as before) or letting
the life screen's actions nudge the clock; neither is built.

**Dependencies.** The time system (`GameDay`, `GameDynasty.world_seconds`, `GameClock.feed`), nothing from the economy.
`tests/test_game_shops.gd` `test_hours_gate` checks open, warning, shut, no grace, refusals of buy, sell and sell_material, `open_here`, and that the
six old services have no hours.

## 1. Enchanting as a shop service (built)

**As built** (`core/game/game_enchant.gd`, `data/shops/enchant.json`, the Kingshold enchanter's `services` row, `ui/play/shop_panel.gd` `_build_enchant`, `tests/test_game_enchant.gd`). It follows the specification below, with these differences, all forced by how made gear is stored:

- **One more affix is the next rarity up.** A made piece's id carries exactly as many affixes as its rarity says (`GameLoot.parse` refuses any other), so adding an affix moves the piece one step up craft.json's `rarity_by_essences` ladder: no affix to fine, fine to rare, rare *or epic* to legendary. A piece with three affixes (legendary) is full; a mythic is refused. The old `max_enchants` counter is dropped: the three-affix cap bounds it, and the piece's id cannot record which of its affixes came from a shop.
- **No level rule.** The spec's "heir's level at least the affix's tier" is always true (tiers open with the generation), so it is not checked; the shop's tier is (`tier_limit`: the town's `shop_tier` plus the shop's `tier_bonus`, held to the row's `tier_cap`; Kingshold's enchanter works to tier 4).
- **Fee** is `base_fee` (120) times the square of the piece's *material tier* times (1 + 0.5 for each affix already held), then `GameItems.price_mult` and the Enchanter's `forge_fee_mult`. The affix is chosen by the heir from those its slot and tier allow; the essence of it must be in the family's stores or bought outright (`essence_fee` 40 gold times the affix's tier).
- **Risk**: the Kingshold row is `safe`. A `risky` row fails `fail_per_tier` (10%) for each tier above 1 on dice keyed on the seed, the piece, the affix and the family's count (`stores.enchanted`); a failure loses the essence and keeps the fee, and never harms the piece.
- **State**: nothing new is saved but the stores' `enchanted` count (loaded clean with `crafted` and `brewed`) and the new id where the old one was (worn slot or pack). No `GameReplay` op: crafting and salvaging are not ops either (the screens do not record).
- **UI**: the enchanter's tab has an Enchanting section: the made pieces the heir carries or wears (Choose, with the reason in the tooltip when a piece cannot be worked), then for the chosen piece each affix that fits (essences held, the fee, the failure chance, what it becomes, Enchant, and Buy essence when none is held). Every refusal is text.

The original specification follows (the parts above override it where they differ).

### Specification

**Where.** The `enchanter` shop (Kingshold, 10:00-20:00, `tier_bonus` 1) is the first; the `scroll_shop` and the `guild_hall` are candidates. A shop offers it by
having a `services` row of kind `enchant` (the row shape below). The shelf and the service are separate tabs of the same panel.

**What it is.** The service adds **one affix** to a piece of gear the heir carries, using the loot generator's own affix list (`data/items/loot.json`,
`GameLoot.pick_affixes`, `GameLoot.build`), so an enchanted piece is the same kind of item as a dropped or crafted one: its id is rebuilt from
`gen:<rarity>:<slot>:<form>:<material>:<affixes>:<mythic>:<grade>:<quality>`. The service does *not* make a new kind of item.

**Eligibility.**
- The item is a `gen:` piece (made or dropped), in the pack or worn. A fixed shop item (`items.json`) is not eligible (it has no affix slots): it must be
  *remade* at the forge first (`GameCraft`).
- It is not unique (`unique` items), not mythic, and has fewer than the rarity's affix slots (`GameLoot` rarity table: common 0-1, fine 1-2, rare 2-3,
  legendary 3-4; mythic cannot be enchanted: `GameCraft.validate` already refuses a crafted mythic).
- The heir's level is at least the affix's tier (`min_level`), and the shop's tier (`shop_tier` of the town plus `tier_bonus`) is at least the affix tier.
- Each piece can be enchanted at most `max_enchants` (suggested 2) times in its life, counted by its affix count above its rarity's base.

**Materials / items.** An **essence** of the affix is required (`GameDynasty.stores.essences`; the stores' essences come from salvage and hunts: "a pelt keeps
the wolf"). The service consumes one essence of the chosen affix. An enchanter may also *sell* an essence of a tier at a shelf price (a `materials`
pool with `essence: true`) so a heir without salvage can still buy a way in. This keeps one economy: essences are the only affix currency, whether found, made or bought.

**Pricing / currency.** Gold only. `price = base_fee * tier^2 * (1 + 0.5 * affixes_already)` with `base_fee` in the service row, then `GameItems.price_mult(d)`
(the town's faction standing and haggling, `GameFactions.town_mult`, a running world event's `price_mult`) and the Enchanter calling's perks
(`forge_fee_mult` is the right existing key: it already scales forge fees; `essence_mult` stays on drops). Prices scale with the generation the way
`GameItems` prices do. Nothing new is added to the heir's economy: gold out, essence out, one affix in.

**Risk / failure / tiers.** Two options, one chosen per shop by a `risk` field (default `safe`):
- `safe` (the enchanter's own work): always succeeds. The cost is the fee and the essence.
- `risky` (a cheaper, lesser shop): a roll **on dice keyed on the seed, the item id and the heir's enchant count** (never the dynasty's `rng`) with
  `fail_chance` from the affix tier (suggested 0 at tier 1 rising 10 points a tier). On failure the essence is lost and the gold is kept by the
  shop; the piece is **never destroyed or downgraded** (the game has no wear and no loss of gear except raids). A heir with a `luck` trait does not change
  the roll; only the Enchanter calling's `forge_fee_mult` and `craft_quality_mult` matter.
Rarity rises with the affix count the same way `rarity_by_essences` does (1 → fine, 2 → rare, 3 → legendary); the service **never** produces mythic.

**UI flow** (`ui/play/shop_panel.gd`, tab "Enchant"). A list of eligible items (name, current affixes, rarity); selecting one shows the affixes that fit its slot
and tier (name, effect from `effect_labels`, essence needed *and held*, fee); a single "Enchant" button (disabled with the reason as text: no essence,
no gold, piece full, shop too small, shop shut); a confirmation line with the result ("`Tess` has Kassel's coat enchanted: of Embers.") written to the
journal like any shop line. Nothing is hidden: the preview is `GameCraft.plan`-style (`plan` says what a choice would make and why not, nothing spent).

**Data shape** (a `services` row; validated by `GameShops.validate`, `tools/check_data.gd`):
```
{"id": "enchant", "kind": "enchant", "name": "Enchant a piece", "desc": "...",
 "base_fee": 120, "risk": "safe", "max_enchants": 2, "tier_cap": 3}
```
**Code.** A new `GameEnchant` (core, no UI) with `eligible(d, shop, item)`, `options(d, shop, item)`, `price(d, shop, item, affix)`, `plan(...)`, `apply(...)`;
`GameShops.serve` dispatches on `kind`. The enchanted id replaces the pack entry (or the worn slot). Text through `GameMessages`/`shops.json text`.
No save change: the item id *is* the state. `GameReplay.OPS` needs an `enchant` op (a new way for the player to change the game).

**Autopilot.** It never calls it (it uses only the six old services), so no seeded life or golden digest moves; the Enchanter calling's perks stay unmeasured
by the autopilot (see BALANCE.md).

## 2. Spellcasting as a shop service (built)

**As built** (`core/game/game_casting.gd`, `data/shops/casting.json`, `cast` rows in `data/shops/shops.json`, `GameDynasty.blessing` and `casts_used`, `ui/play/shop_panel.gd` `_build_casting`, `tests/test_game_casting.gd`). It follows the specification below, with these particulars:

- **For sale:** only the party-shaped utility spells: `mass_heal` (healing), `cleanse` (cleansing) and `ward`, `haste`, `rejuvenation` (blessings). The validator refuses a spell with any other target shape, so nothing aimed at foes is ever sold. Rows: the Kingshold spell shop (all five, caster level 8), the apothecary (cleanse, level 4), the herbalist (rejuvenation, level 3) and the Ironford shrine (mass heal level 6, ward level 5). The temple's own services are the old ones and are untouched.
- **Outside a fight** (the only time a shop casts): a healing spell mends the heir and every companion at once by the spell's own `pct_max_hp` times the caster's strength; a cleansing spell cures every sickness the heir has (and mends its small share); a blessing is laid on the party for the **next fight** and applied to the heir and every companion when it begins (`GameDynasty._begin_battle` asks `GameCasting.on_battle`), using the spell's own statuses and turns. No time passes and no dice are drawn.
- **Strength and price:** `level_step` (3%) stronger and `price_step` (10%) dearer for each caster level above 1; the price is the spell's own `mp` times `mp_gold` (6) times that, then `GameItems.price_mult`. The heir's own mana is not spent.
- **Blessing rules:** one at a time (a second replaces it, and says so); it lapses after its `fights` (1), after its `years` (1) of the world's calendar, and with its heir (it records the generation); buying the same blessing again at the same or lower strength while it is laid is refused.
- **Cooldown:** the same spell at the same shop once a day of the world clock (`day_mark`: the world year and `GameDay`'s day number); a row may switch it off (`daily: false`). The life screen's clock stands still, so there the cooldown lasts until the open world's day has passed.
- **State:** `blessing` and `casts_used` are saved only when set and loaded clean (`GameCasting.load_blessing`, `load_used`); the autopilot never casts, a fight with no blessing begins exactly as before (the test compares), so no seeded life, golden digest or balance number moves. No `GameReplay` op (nothing the shops do is an op yet).
- **UI:** the shop's tab has a Spells section: a line naming the blessing now laid, then each spell with its effect text, kind, price and a Cast button (disabled with the reason as text: no gold, nothing to mend, no sickness, on cooldown, shop shut, in a fight).

The original specification follows (the parts above override it where they differ).

### Specification

**Where.** The `temple`/`shrine` (healing and cleansing, always open: they are old services), the `apothecary`/`herbalist` (cleansing), the `scroll_shop`
and `guild_hall` (utility and buffs for pay), and the `enchanter`. A service row of kind `cast` names a spell from `data/spells/spells.json` and who casts it.

**Available spells.** Only the spells whose `target.shape` is `party` or `single` and group `utility` are for sale, because the service acts on the heir and the party,
not on foes: `mass_heal`, `rejuvenation` (healing), `cleanse` (cleansing), `ward`, `haste` (buffs), `expose_weakness`/`mana_tap` are battle-only and excluded. Elemental
and control spells are never a service (they have no target at a shop).

**Casting context.** Two contexts, one rule each:
- **Outside a fight** (the life screen, the town): healing and cleansing are *instant* effects, like the bath (`heal` share, `cure` of a `GameDisease` the heir
  has, no time passes, no dice). A buff cast outside a fight is a **blessing** that lasts for the **next fight**, then lapses (a flag on `d` such as
  `blessing: {spell, fights_left}`, saved only when set, loaded clean; `GameBattle` starts with it applied as the spell would be, using the spell's own
  effect at the caster's level).
- **In a fight**: not offered. A shop is not a battle mage.

**Costs.** Gold only, `price = mp * mp_gold * tier_factor`, where `mp` is the spell's own `mp` (the existing numbers: cleanse 6, haste 10, mass heal 12), `mp_gold` a
setting per shop (suggested 6 gold per mp, the same unit as `GameShops.unit_price`'s material unit), then the usual `price_mult`. A caster's level (`caster_level`
in the row) sets the spell's strength; a higher-tier shop casts at a higher level at a higher fee. The heir's own MP is **not** spent (it is a *purchase*, not a cast).

**Cooldown / duration.**
- Healing and cleansing: once per shop per **day** (`GameDay` day number kept in `d.shop_state` or a new small `services_used` dict, saved only when set): a temple heals you as often as you
  like today (the old service); the new ones are limited so they are not a free full heal every fight. `cooldown_days` in the row (suggested 1; 0 for none).
- A blessing: **one active blessing at a time**; a second purchase replaces it (no stacking). It lasts `fights` fights (suggested 1) and no more than `years` years (suggested 1), so a
  forgotten blessing does not carry across a generation. A heir's death clears it.
Nothing is a rest: no years pass (rest stays the bed's use).

**UI flow.** A "Spells" tab: rows of spell name, effect line, price, "Cast" button (disabled with reasons: no gold, nothing to heal, no disease to cleanse, a blessing
already active and what it will replace, on cooldown until tomorrow, shop shut), a result line in the journal. A blessing shows in the life screen header next to the weather
as one word and a count.

**Data shape.**
```
{"id": "bless_ward", "kind": "cast", "spell": "ward", "name": "A ward", "desc": "...",
 "mp_gold": 6, "caster_level": 5, "cooldown_days": 1, "fights": 1}
```
**Code.** `GameCasting` (core, no UI): `offers(d, shop)`, `price`, `why_not`, `cast(d, shop, id)`; `GameBattle` reads `d.blessing` at the start; `GameShops.serve` dispatches
on `kind`; `GameReplay.OPS` gets a `cast_service` op. The save format gains an optional key (`blessing`, `services_used`), written only when set and loaded clean; if it
is ever made *required*, it goes in `GameSaves.REQUIRED` only when old saves have it.

**Dependencies.** Spells (`GameBattle.cast_spell`, `spell_cost`), diseases (`GameDisease`, cure), the day clock (`GameDay`), the economy (`GameItems.price_mult`, `mp_gold`).
The autopilot never buys one, so no balance number moves; once the heir can buy a blessing a *manual* life is stronger by a bounded amount, which
BALANCE.md's non-autopilot-perk method measures.

## Files

Built: `core/game/game_shops.gd`, `data/shops/shops.json` (`text`, `last_call_hours`), `ui/play/shop_panel.gd`, `ui/play/life_screen.gd`, `tests/test_game_shops.gd`, `CLAUDE.md`.
To build: `core/game/game_enchant.gd`, `core/game/game_casting.gd` (new, with `.uid` files), `data/shops/shops.json` rows, `GameShops.validate`, `ui/play/shop_panel.gd` tabs,
`core/game/game_replay.gd` ops, `core/game/game_dynasty.gd` (`blessing`, `services_used`, saved only when set), `data/text` lines, tests (`test_game_enchant.gd`, `test_game_casting.gd`).

## 2b. The heir's own spells: the same system, paid in MP (built)

Spellcasting used to exist twice: the shops' (`GameCasting`) and a dungeon-only table for the heir's own spells (`GameDungeonSpells`, `spells` in `dungeons.json`), which applied the same spells by different rules (Cleanse only healed, Rejuvenation healed at once, Ward was a flag of the visit). They are now **one system with two payers**:

| | Shop | The heir's own |
|---|---|---|
| Pays | gold (`price`), a daily cooldown per shop and spell | MP (the spell's own cost, as `GameSkillTree` shapes it) |
| Needs | the shop open and in town; the spell need not be known | the spell known; outside a fight (`GameSandbox.cast` keeps its screen button to dungeons) |
| Strength | `caster_level` of the row | the heir's own healing power (`GameBattle.heal_amount`); blessings at level 1 |
| Kinds | one table, `casting.json` `settings.kinds`: **healing** (mass_heal), **cleansing** (cleanse), **blessing** (ward, haste, rejuvenation) | the same |

- **Healing** mends the heir and every companion; refused, and free, when everyone is whole. **Cleansing** cures every sickness (refused and free with none). **Blessing** is laid on the party for the next fight (`self_fights` fights, `self_years` years) and replaces another; the same one is not laid twice.
- **The ward** is a blessing like any other, and `settings.trap_wards` lists the ones that also turn the **next hidden trap** of a dungeon (`GameCasting.ward_up`, asked as the heir steps; `spend_ward` records it as `trap_spent` in the saved blessing, and it still blesses the next fight). It makes no difference who laid it: a ward from the spell shop turns a trap just as the heir's own does. It no longer drops when the heir leaves the dungeon (it was a flag of the visit); it waits like any blessing.
- **Saved:** nothing new except the optional `trap_spent` mark in the blessing, written only once a ward has been used on a trap and loaded clean (a damaged mark is dropped; old saves load as they were). No dice. The autopilot never casts.
- **Changed from the old dungeon spells (said plainly):** Cleanse now cures sickness; Rejuvenation is a blessing for the next fight, not an instant heal; Haste can be cast; a ward persists to the next fight. `tests/test_game_self_cast.gd` checks all of it.
- Not built: casting damage or control spells outside a fight, a Cast button outside dungeons (the sandbox's bar would change its stored screenshots), caster level for the heir's own blessings.

## Open numbers needed for a full pass

`base_fee`, `fail_chance` per tier, `max_enchants`, `mp_gold`, `caster_level` per shop tier, `cooldown_days`, blessing `fights`/`years`; whether the Enchanter calling's
perk reduces the service fee or only the forge's (suggest: the service fee too, through `forge_fee_mult`); whether the life screen should let hours pass.
