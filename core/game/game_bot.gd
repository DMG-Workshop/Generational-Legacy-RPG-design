## Simple autopilot used by tests and the "Auto-live" button. Deterministic (no RNG of its own).
class_name GameBot
extends RefCounted


## Fights the battle in progress to the end with GameTactics (potions and heals when low, areas
## against packs, control on the worst foe), settles it and searches the dead or leaves them.
static func fight(d: GameDynasty) -> void:
	var b := d.battle
	var guard := 0
	while not b.is_over() and guard < 300:
		guard += 1
		GameTactics.auto_turn(b)
	d.finish_battle()
	GamePlague.bot_loot(d)


## One decision for the current life. Returns false once the heir has died.
static func step(d: GameDynasty) -> bool:
	var h := d.heir
	if d.state != "life":
		return false
	if d.has_pending_event():
		GameEvents.bot_resolve(d)
		return d.state == "life"
	GameItems.bot_tick(d)
	GameQuests.bot_tick(d)
	GameParty.bot_tick(d)
	GameSkillTree.bot_tick(d)   # before feats: the feats are weighed with the tree's numbers
	GameFeats.bot_tick(d)
	var hp_frac := float(h.hp) / float(h.max_hp())
	while h.potions < 3 and h.gold >= d.potion_price() * 2:
		d.buy_potion()
	if hp_frac < 0.55:
		d.rest()
	elif d.can_found_family():
		d.found_family()
	else:
		var boss := d.available_boss()
		var target := _legend_to_hunt(d)
		if not boss.is_empty() and h.level >= int(boss.get("min_level", 99)) and hp_frac > 0.85:
			d.start_legend()
			fight(d)
		elif not target.is_empty() and hp_frac > 0.85:
			var path := d.world.route_to(target["lair"], d.flags)
			d.travel(path[0])
		elif GameEvents.bot_wants_explore(d):
			d.explore()
			if d.has_pending_event():
				GameEvents.bot_resolve(d)
		elif (h.battles_won + h.level) % 5 == 4:
			d.train(["str", "vit", "agi", "mag"][(h.battles_won + h.level) % 4])
		else:
			d.start_hunt("hunt_hard" if wants_hard_hunt(d) else "hunt")
			fight(d)
	return d.state == "life"


## True when the autopilot should take a Hard hunt (double rewards, harder foes) instead of a plain
## one: only a seasoned heir at (near) full health, with potions in hand, gear worn and a run of
## clean wins behind them (GameHeir.clean_streak: wins that left at least `clean_hp_frac` of HP, so
## a costly Hard hunt sends the bot back to plain ones), in a place no deadlier than the rule
## allows; and then only one hunt in `every`. The rule lives in balance.json "bot_hard_hunt"; `every` 0 turns Hard hunts off.
## Deterministic and cheap: it reads only the heir and the place, never the RNG.
static func wants_hard_hunt(d: GameDynasty) -> bool:
	var r: Dictionary = GameData.bal("bot_hard_hunt")
	var h := d.heir
	var every := int(r["every"])
	if every <= 0 or h.level < int(r["min_level"]) or h.potions < int(r["min_potions"]):
		return false
	if h.clean_streak < int(r["min_streak"]) or float(h.hp) < float(r["min_hp_frac"]) * float(h.max_hp()):
		return false
	var gear := 0
	for slot in h.equipment:
		if str(h.equipment[slot]) != "":
			gear += 1
	if gear < int(r["min_gear"]):
		return false
	if float(d.world.here().get("danger", 1.0)) > float(r["max_danger"]):
		return false
	return h.battles_won % every == 0


## A stirring legend the heir is strong enough for, with a reachable lair elsewhere.
static func _legend_to_hunt(d: GameDynasty) -> Dictionary:
	for c in d.stirring_legends():
		var lair: String = c.get("lair", "")
		if lair != "" and lair != d.world.location and d.heir.level >= int(c.get("min_level", 99)) and not d.world.route_to(lair, d.flags).is_empty():
			return c
	return {}


static func live_life(d: GameDynasty) -> void:
	var guard := 0
	while d.state == "life" and guard < 1000 + int(d.heir.lifespan):
		guard += 1
		if d.heir.age >= minf(d.heir.lifespan, d.heir.compute_lifespan(false)) * 0.9 and d.can_retire():
			d.retire()
		else:
			step(d)


static func choose_best(d: GameDynasty) -> void:
	if d.state == "succession":
		d.choose_heir(0)
