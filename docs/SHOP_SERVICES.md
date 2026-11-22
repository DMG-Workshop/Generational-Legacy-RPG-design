# Shop services: enchanting, spellcasting, and opening hours

Design for two paid **services** a shop does *for* the heir (as opposed to selling a thing off a shelf), and for the life screen's **Shops** button keeping
shop hours. Status: **opening hours are built and tested** (below); enchanting and spellcasting are **specified**, with the data shape and the places they plug in.

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

## 1. Enchanting as a shop service (specified)

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

## 2. Spellcasting as a shop service (specified)

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

## Open numbers needed for a full pass

`base_fee`, `fail_chance` per tier, `max_enchants`, `mp_gold`, `caster_level` per shop tier, `cooldown_days`, blessing `fights`/`years`; whether the Enchanter calling's
perk reduces the service fee or only the forge's (suggest: the service fee too, through `forge_fee_mult`); whether the life screen should let hours pass.
