## Spells cast outside a battle, in a dungeon (data/world/dungeons.json `spells`, checked by GameDungeons.validate). A spell the heir
## knows (GameHeir.spells, learned by class and level as ever) that has an entry there can be cast on the sandbox's floor: `heal`
## mends the heir (and, when the entry says `party`, every companion) by the spell's own share of maximum health (`pct` in the
## entry replaces it, for a spell that heals over time in a fight) and `ward` turns the next hidden trap the heir steps on.
## The cost is the spell's, as GameSkillTree shapes it, paid in MP (Blood Magic is not honoured here). No dice are drawn, nothing
## here is saved beyond the heir's MP and health (and the companions' health), which the life keeps anyway. The autopilot never casts.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_spells.gd
class_name GameDungeonSpells
extends RefCounted


static func entries() -> Dictionary:
	return GameDungeons.data()["spells"]


static func text(key: String, vals: Dictionary = {}) -> String:
	return GameDungeons.text(key, vals)


## The spells the heir can cast here: [{id, name, cost, effect, can, why}] in their spell-list order. `can` is whether they have
## the MP; `why` says what is lacking when they do not.
static func castable(d: GameDynasty) -> Array:
	var out: Array = []
	if d.heir == null:
		return out
	for id in d.heir.spells:
		if not entries().has(str(id)):
			continue
		var sp := GameSkillTree.spell(d.heir, str(id))
		if sp.is_empty():
			continue
		var cost := GameCombat.ability_cost(sp, d.heir.level)
		var enough := d.heir.mp >= cost
		out.append({"id": str(id), "name": str(sp.get("name", id)), "cost": cost, "effect": str(entries()[str(id)]["effect"]), "can": enough,
			"why": "" if enough else text("spell_no_mp", {"name": str(sp.get("name", id)), "cost": cost})})
	return out


## Whether the heir (or a companion, when `party`) is below full health.
static func hurt(d: GameDynasty, party: bool) -> bool:
	if d.heir.hp < d.heir.max_hp():
		return true
	if party:
		for m in d.party.members:
			if int(m["hp"]) < d.party._body(d, m).max_hp():
				return true
	return false


## Casts a spell. {ok, text, effect}: refused (nothing paid) for a spell not known or without an entry, without the MP, or a heal
## when everyone it would reach is whole. `warded` is whether a ward is already up (a second is refused).
static func cast(d: GameDynasty, id: String, warded: bool = false) -> Dictionary:
	if d.heir == null or d.battle != null or id not in d.heir.spells or not entries().has(id):
		return {"ok": false, "text": text("spell_unknown"), "effect": ""}
	var sp := GameSkillTree.spell(d.heir, id)
	var entry: Dictionary = entries()[id]
	var cost := GameCombat.ability_cost(sp, d.heir.level)
	var name := str(sp.get("name", id))
	if d.heir.mp < cost:
		return {"ok": false, "text": text("spell_no_mp", {"name": name, "cost": cost}), "effect": str(entry["effect"])}
	match str(entry["effect"]):
		"heal":
			var party := bool(entry.get("party", false))
			if not hurt(d, party):
				return {"ok": false, "text": text("spell_whole", {"h": d.heir.name}), "effect": "heal"}
			d.heir.mp -= cost
			var pct := float(entry.get("pct", sp.get("pct_max_hp", 0.1)))
			var n := _heal(d.heir, pct)
			var mended: Array = [d.heir.name]
			if party:
				for m in d.party.members:
					var body := d.party._body(d, m)
					var room := body.max_hp() - int(m["hp"])
					if room <= 0:
						continue
					m["hp"] = int(m["hp"]) + mini(room, GameBattle.heal_amount(d.heir, body, {"pct_max_hp": pct}))
					mended.append(str(m["name"]))
			return {"ok": true, "text": text("spell_healed", {"h": d.heir.name, "spell": name, "who": GameMessages.text("life", "list_and").join(mended), "n": n}), "effect": "heal"}
		"ward":
			if warded:
				return {"ok": false, "text": text("spell_warded"), "effect": "ward"}
			d.heir.mp -= cost
			return {"ok": true, "text": text("spell_ward", {"h": d.heir.name, "spell": name}), "effect": "ward"}
	return {"ok": false, "text": text("spell_unknown"), "effect": ""}


static func _heal(heir: GameHeir, pct: float) -> int:
	var n := mini(GameBattle.heal_amount(heir, heir, {"pct_max_hp": pct}), heir.max_hp() - heir.hp)
	heir.hp += maxi(0, n)
	return maxi(0, n)


static func validate() -> Array:
	var bad: Array = []
	var ent: Variant = GameDungeons.data().get("spells")
	if typeof(ent) != TYPE_DICTIONARY or (ent as Dictionary).is_empty():
		return ["dungeons.json: spells is missing"]
	for id in ent:
		var sp := GameCombat.spell(str(id))
		var e: Dictionary = ent[id]
		if sp.is_empty():
			bad.append("dungeons.json: spells.%s is not a spell" % id)
		if str(e.get("effect", "")) not in ["heal", "ward"]:
			bad.append("dungeons.json: spells.%s has an unknown effect" % id)
		if str(e.get("effect", "")) == "heal" and float(e.get("pct", sp.get("pct_max_hp", 0.0))) <= 0.0:
			bad.append("dungeons.json: spells.%s heals nothing" % id)
	return bad
