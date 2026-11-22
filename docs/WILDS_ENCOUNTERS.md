# Wilds: landmarks that start fights, and the merchant panel

Design for two missing pieces of the open world's wilds (see `CLAUDE.md` "The wilds"). Status: **specified**; nothing here is built. It reuses what exists:
`GameWildsSites` (landmarks, `use`, `used`), `GameSandbox.use()` and `offer()`, `GameSandbox._contact()` and `GameDynasty.start_encounter(ids, place)`, the
area spawn tables (`data/creatures/spawn.json` `areas`), `GameWildsLoot`, the shop panel (`ui/play/shop_panel.gd`), and the map-fight stand-in (`ui/play/map_fight.gd`).

## 1. Landmarks that start fights

A landmark kind in `data/world/wilds.json` `landmarks` (the kinds with `outcomes`, a `trade` flag, `renew_gens`) gains an optional **`encounter`** block.

### Trigger conditions

Two triggers, set per kind:
- **`approach`**: the heir comes within `trigger_range` tiles (suggested 3-5) of the landmark's centre, *and* `GameWilds`'s reach line is clear (`GameWalls.line_clear`
  with no stoppers in the wilds today, so this is distance). Fires once per **visit** (see re-trigger).
- **`use`**: the heir uses the landmark (`GameSandbox.use()` within `use_reach`) and the kind's `outcomes` roll an `ambush` outcome. This is the existing use path with
  one more outcome kind, so it needs no new input.
A kind may have both (a bandit camp: approach wakes the guards; looting the chest springs the rest). The default for existing kinds is **no encounter**, so nothing changes
for a shrine or a farm.

### Encounter tables and difficulty scaling

- **Who**: `encounter.table` names a weighted pool, or `"area"` to use the place's own spawn table (`spawn.json` `areas[area_of(x,z)]`, which already has `weights`, `add` and
  `density`), or a fixed list (a bandit camp: `bandit`, `bandit_archer`, plus a leader). A creature must be of the area's era and biomes (the validator checks, as for `GameDungeons.foes`).
- **How many**: `count: [min, max]` rolled on dice keyed on the seed, landmark id and trigger count (never the dynasty's `rng`), capped by `GameSandbox.setting("contact_max")`.
- **How strong**: `danger` (a share of the area's level, as `GameDungeons` uses the dungeon's `danger`), levels round the heir's through `GameDynasty.start_encounter(ids, place)` with the hunt's own rules
  (`balance.json` `hunt_rewards.hunt`), and the encounter scales with the generation the way hunts do. A `boss` slot may name one stronger creature (an elite), at most one, from the area's `fixed` list.
- **Rewards**: the fight's own (`finish_battle`); the landmark's `outcomes` loot (`GameWildsLoot.roll`) is added **on a win** instead of at the use, so a camp's chest is the prize for beating its guards.

### Ambush and surprise

Three modes, set by `encounter.ambush`:
- `none`: the foes are placed as agents (`GameBehaviour.new_agent`) at the landmark in `idle`, then go to `chase` when the heir is within their `sight` (the existing creature rules).
  No surprise: the normal fight starts through `_contact()`.
- `hidden`: the foes are **not in the world until triggered**. On trigger, `start_encounter` is called at once with a surprise flag: the heir loses the first round's initiative
  (`battle.surprised = "heir"`: the foes act first, once), unless the heir's class or trait gives `ambush_sense` (rangers and Wayfinder: `flee_mult`-style perk, never a hard block).
- `lair`: a boss that is *stirring* in this generation (see the legends' `lair` rule), as `start_legend_at`.
A surprise never kills: the same rule as traps (`GameDungeons`: costs a share of health and never kills) applies to the first round; flight is still allowed (`GameBattle.flee`).

### Re-trigger and cooldown

- Stored in `d.wilds.used[id]` (the dynasty's existing record: `{gen, n}`), extended with `fought: world_year` (written only when set, loaded clean by `GameWildsSites.load_state`).
- **Once per visit**: after the heir leaves `leave_range` (suggested 3x `trigger_range`) and returns, the landmark may trigger again, but not before `renew_years` of the world clock
  (`GameDay`/`world.year`; suggested 1 year for a camp, never for a shrine) *and* not twice in the same generation unless the kind says `repeatable`.
- A **win** marks the landmark `cleared` for `renew_gens` generations (the same field as a used landmark: nothing to fight until it renews). A **flight** leaves it
  uncleared and the survivors in the world (as `GameSandbox` keeps a fled creature); a **defeat** is the normal defeat.
- The heir's own `fled` escape tile (`GameDynasty.sandbox_escape`) is already how a fight on the map returns; an encounter reuses it.

### Where it plugs in

`GameWildsSites.encounter_for(d, id)` (pure: the kind's block, the rolled foes and mode), `GameSandbox.refresh()` (already calls `discover_near`; it would call `approach` triggers),
`GameSandbox.use()` (an `ambush` outcome), `GameSandbox._contact()` (placed foes), `GameDynasty.start_encounter`. The map fight screen needs nothing new. `tests/test_game_wilds_encounters.gd` would
cover: a trigger, the foes' levels and count by generation, surprise once, the cooldown and `cleared`, save/load of `fought`, and that the autopilot (which never walks the wilds) is untouched.

## 2. The merchant panel

Today a wilds `trade` landmark offers **one** item at `markup` (`GameSandbox.offer`, never saved) and sells it on the second Use. The panel replaces the two-step Use with a small
shop that opens as a modal over the map (the world waits while a `modal` panel is open, like the sandbox's service panels).

### Layout

`ui/play/merchant_panel.gd` (a `ShopPanel`-style panel; it reuses the same row builders `_item_row`, `_service_row`): header (who, where, the area's name, "wandering trader"), three sections in a
scroll: **Buy** (the stock), **Sell** (what the heir carries that the trader takes), **Trade** (barter rows). A footer with gold, pack weight (`GameCarry`) and a Close button (B/Escape closes, as the
other panels' `back_close` meta). Touch targets are at least `touch_target_px`; the reduced-motion and high-contrast conventions apply (`Kit.quiet_bb` for quiet lines).

### Actions

- **Buy**: an item at the trader's price (`price = item price * markup * GameItems.price_mult(d)`, `markup` from the landmark kind). Disabled with a reason: no gold, `GameCarry.can_carry`, already owned
  (non-stackable gear). Same refusals as `GameShops._buy`.
- **Sell**: from the pack, at the trader's `buy` share of the sell price (`GameItems.sell_price`), for **kinds the trader wants** (`wants` tags: a hermit wants herbs and potions, a peddler anything).
  Never unique or worn gear.
- **Trade (barter)**: "N of material for 1 item or for gold": rows `{give: {materials}, get: {item or gold}}` drawn from the trader's table, so a heir with ore and no gold can still deal. Uses the family stores
  (`GameCraft.have`/`add_material`), the same as `GameShops.sell_material`.

### Currency

Gold, with **materials** as barter. No new currency. Prices follow the same multipliers as every shop (the town's faction does not apply in the wilds: `GameFactions.town_mult` is 1.0 there; a running world event's
`price_mult` and the Caravaneer's `buy_mult`/`sell_mult` do).

### Inventory refresh and stock limits

- **A trader's stock is generated, not stored**: a pure function of the seed, landmark id, `renew` period and the generation, in the same style as `GameShopStock` (dice keyed on those, never the dynasty's), drawing
  from `wilds_loot.json`'s tables and the area's `trade` pool. It is stable while the trader stays and *changes at renewal*.
- **Sold out**: as the town shelves (`GameDynasty.shop_sold`): each entry is one of its kind; a purchase records it under the landmark's id and the renewal period; the record is dropped at renewal.
- **Stock limit**: `stock: [min, max]` entries (suggested 3-6), at most one item per slot category so the panel is short on a phone.
- **Renewal**: every `renew_gens` generations (the existing field) *or* when the landmark is cleared by a fight; a trader that is attacked is not a trader (not built: no attacking a peddler).

### Interaction flow

`Use` beside the trader (existing) → `GameSandbox.use()` returns `{ok, open: "merchant", landmark: id}` (like the forge: `open` names the panel) → the screen opens `MerchantPanel` as a modal → buy/sell/trade call
`GameWildsSites` trade methods (`stock`, `buy`, `sell`, `barter`) → results go to the journal → Close returns to the world. A trader has **no hours** (it is a person on the road); it may be `wary` (does not trade
while an encounter at the same landmark is uncleared, which ties the two features together: a bandit camp's wagon is looted after the guards fall).

### Where it plugs in

`core/game/game_wilds_sites.gd` (trade methods), `data/world/wilds.json` (`landmarks[*].trade` becomes a table: `markup`, `wants`, `stock`, `barter`), `data/items/wilds_loot.json` (trade pools),
`ui/play/merchant_panel.gd` (new, with `.uid`), `ui/play/sandbox_screen.gd` (`_open_service` handles `merchant`), `core/game/game_dynasty.gd` (`shop_sold` already keyed by place, so a landmark id works as the key),
`GameReplay.OPS` (`trade_buy`, `trade_sell`, `barter`), `tests/test_game_merchant.gd`.

## Remaining assumptions / numbers needed

`trigger_range`, `leave_range`, `renew_years`, `count`, `danger` and `stock` ranges per landmark kind; how strong surprise is (one free round?) and which classes sense ambushes; whether a cleared camp
pays more loot than an unfought one (suggested: the loot is only given on a win); whether wandering traders walk (they do not today: landmarks are fixed). The wilds' creatures have no `ranged` behaviour tag
yet, so an archer's reach is the contact rule until REACH.md's ranged rule is built.
