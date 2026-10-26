## Scripted fights for the determinism tests (see test_round_determinism.gd). Uses ONLY battle APIs
## that existed before party command rounds, so the same file runs on the old tree to capture the
## baseline (capture_round_baseline.gd) and on the new one to compare against it.
## Usage: const Scen := preload("res://tests/round_scenarios.gd")
extends RefCounted

const CLASSES := ["mage", "warrior", "rogue", "cleric", "paladin", "spellblade"]
const PARTY_SIZES := [0, 1, 3]
const KINDS := ["hunt", "hunt_hard", "legend"]
const COMPANIONS := ["bren_cask", "sister_oriel", "maddy_thorn", "hulda_stonebrow", "tarsk_ember_eye", "ser_aldric_vane", "old_netta", "grull_one_tusk"]
const MODES := ["bot", "auto_turn", "manual"]
const GUARD := 300


## A dynasty about to fight: class `cls`, `n` companions, a hunt or a legend. Nothing here throws dice
## beyond what the game's own start-of-battle code does, so the same seed starts the same fight.
static func make(seed_val: int, cls: String, n: int, kind: String) -> GameDynasty:
	GameData.load_all()
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	var level := 12 + seed_val % 23
	d.heir.level = level
	d.heir.gold = 5000
	d.heir.potions = 2 + seed_val % 3
	d.heir.learn_spells()
	d.world.visit("kingshold")
	for k in n:
		var id: String = COMPANIONS[(seed_val + k) % COMPANIONS.size()]
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": level, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	if seed_val % 2 == 0:
		for id in GameFeats.ids():
			if GameFeats.requirement_block(d.heir, id) == "" and d.heir.equipped_feats.size() < GameFeats.slots(d.heir):
				d.heir.known_feats.append(id)
				d.heir.equipped_feats.append(id)
	if seed_val % 3 != 1:
		d.heir.inventory.append_array(["nightshade_oil", "plague_vial"])
	if kind == "legend":
		var bosses: Array = GameData.creatures.filter(func(c): return c.get("boss", false))
		var boss: Dictionary = bosses[seed_val % bosses.size()]
		d._begin_battle([d._make_enemy(boss, 1.0, 1.0, mini(level + 4, int(boss.get("min_level", level))))], "legend")
	else:
		d.start_hunt(kind)
	return d


static func key(mode: String, seed_val: int, cls: String, n: int, kind: String) -> String:
	return "%s|%d|%s|%d|%s" % [mode, seed_val, cls, n, kind]


static func digest(payload: Variant) -> String:
	return JSON.stringify(payload, "", true).sha256_text()


## What a fight leaves behind, in one comparable value.
static func state_of(b: GameBattle) -> Dictionary:
	return {"result": b.result, "turn": b.turn, "rng": b.rng.state, "heir": [b.heir.hp, b.heir.mp, b.heir.potions],
		"allies": b.allies.map(func(a): return [a.hp, a.mp]), "foes": b.enemies.map(func(e): return e["hp"]),
		"statuses": b.statuses, "uses": b.uses, "focus": b.focus, "casts": b.casts}


# ---------------------------------------------------------------- the scripted manual heir

## One scripted command for the heir, from the battle's turn number alone (no dice). Always legal
## right now: the same command is given to the direct methods and, in the new tree, to GameRound.
## {"act", "kind", "id", "target"} with refs, the shape GameRound queues.
static func script_cmd(b: GameBattle, seed_val: int) -> Dictionary:
	var living := b.living_enemies()
	var first := "enemy:%d" % living[0]
	var last := "enemy:%d" % living.back()
	var h := b.heir
	var step := (b.turn + seed_val) % 9
	match step:
		1, 7:
			var i := 1 if step == 7 else 0
			if i < b.skill_count() and b.can_use_skill(i):
				var ab := b.skill_info(i)
				if not GameCombat.aims_at_foe(ab):
					return {"act": "ability", "kind": "skill", "id": str(ab["id"]), "target": ""}
				if not b.aoe_hits(ab, -1, living[0]).is_empty():
					return {"act": "ability", "kind": "skill", "id": str(ab["id"]), "target": first}
		2:
			for item in GamePlague.vials_carried(h):
				if b.can_throw(item) and not b.aoe_hits(GamePlague.vial_ability(item), -1, living[0]).is_empty():
					return {"act": "ability", "kind": "vial", "id": str(item), "target": first}
			for id in h.spells:
				var ab := b.unit_spell(-1, id)
				if b.can_cast(id) and GameCombat.aims_at_foe(ab) and not b.aoe_hits(ab, -1, living[0]).is_empty():
					return {"act": "ability", "kind": "spell", "id": str(id), "target": first}
		3:
			for slot in h.equipped_feats.size():
				var id: String = h.equipped_feats[slot]
				var ab := b.unit_feat(-1, id)
				if b.can_use_feat(slot) and (not GameCombat.aims_at_foe(ab) or not b.aoe_hits(ab, -1, living[0]).is_empty()):
					return {"act": "ability", "kind": "feat", "id": id, "target": first if GameCombat.aims_at_foe(ab) else ""}
		4:
			return {"act": "defend"}
		6:
			if h.potions > 0 and h.hp < h.max_hp() * 7 / 10:
				return {"act": "potion"}
		8:
			return {"act": "attack", "target": last}
	if seed_val % 7 == 0 and b.turn == 5 and b.allies.is_empty():
		return {"act": "flee"}
	return {"act": "attack", "target": first}


## Whether the script wants a toxin on the blade before this turn (a free action).
static func script_coat(b: GameBattle, seed_val: int) -> String:
	if b.turn % 4 != seed_val % 4 or not b.coating.is_empty() or b.heir_skip:
		return ""
	for id in b.heir.inventory:
		if b.can_coat(id):
			return str(id)
	return ""


static func _idx(ref: String) -> int:
	return int(ref.get_slice(":", 1)) if ref.begins_with("enemy:") else -1


## The heir's command through the battle's own public methods, as the UI always did.
static func direct(b: GameBattle, cmd: Dictionary) -> void:
	var t := _idx(str(cmd.get("target", "")))
	match str(cmd["act"]):
		"attack":
			b.attack(t)
		"defend":
			b.defend()
		"potion":
			b.use_potion()
		"flee":
			b.flee()
		"ability":
			match str(cmd["kind"]):
				"skill":
					var skills: Array = GameSkillTree.skills(b.heir)
					for i in skills.size():
						if str(skills[i]["id"]) == str(cmd["id"]):
							b.use_skill(i, t)
							return
				"spell":
					b.cast_spell(str(cmd["id"]), t)
				"feat":
					b.use_feat(b.heir.equipped_feats.find(cmd["id"]), t)
				"vial":
					b.throw_vial(str(cmd["id"]), t)


# ---------------------------------------------------------------- runs

## Plays one fight in `mode` ("bot": GameBot.fight; "auto_turn": stepped auto_turn; "manual": the
## scripted heir through direct calls) and returns {digest, lines, log?}.
static func run(mode: String, seed_val: int, cls: String, n: int, kind: String, with_log: bool = false) -> Dictionary:
	var d := make(seed_val, cls, n, kind)
	var b := d.battle
	var trail: Array = []
	var guard := 0
	match mode:
		"bot":
			GameBot.fight(d)
		"auto_turn":
			while not b.is_over() and guard < GUARD:
				guard += 1
				GameTactics.auto_turn(b)
				trail.append([b.log.size(), b.events.duplicate(true)])
			d.finish_battle()
		"manual":
			while not b.is_over() and guard < GUARD:
				guard += 1
				var coat := script_coat(b, seed_val)
				if coat != "":
					b.coat_blade(coat)
					trail.append([b.log.size(), b.events.duplicate(true)])
				var before := b.turn
				direct(b, script_cmd(b, seed_val))
				if b.result == "" and b.turn == before:   # the battle turned the command down: a plain blow
					b.attack(b.first_target())
				trail.append([b.log.size(), b.events.duplicate(true)])
			d.finish_battle()
	var payload := {"log": b.log, "trail": trail, "state": state_of(b), "dynasty": d.to_dict()}
	var out := {"digest": digest(payload), "lines": b.log.size()}
	if with_log:
		out["log"] = b.log
	return out


## A few lives of the autopilot: the whole save after each generation.
static func live(seed_val: int) -> Dictionary:
	GameData.load_all()
	var d := GameDynasty.new_game(seed_val, "Tess", CLASSES[seed_val % CLASSES.size()], "faetouched", "human")
	var shots: Array = []
	var gens := 0
	while gens < 3 and d.state != "ended":
		GameBot.live_life(d)
		shots.append(d.to_dict())
		gens += 1
		if d.state == "succession":
			GameBot.choose_best(d)
	return {"digest": digest(shots), "lines": d.journal.size()}


## Every scenario key in order.
static func all_keys(seeds: int = 40) -> Array:
	var out: Array = []
	for s in range(1, seeds + 1):
		for ci in CLASSES.size():
			for pi in PARTY_SIZES.size():
				var kind: String = KINDS[(s + ci + pi) % KINDS.size()]
				for mode in MODES:
					out.append(key(mode, s, CLASSES[ci], PARTY_SIZES[pi], kind))
	for s in range(1, 7):
		out.append("live|%d" % s)
	return out


static func run_key(k: String, with_log: bool = false) -> Dictionary:
	var p := k.split("|")
	if p[0] == "live":
		return live(int(p[1]))
	return run(p[0], int(p[1]), p[2], int(p[3]), p[4], with_log)
