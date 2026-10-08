## The whole dynasty simulation: one living heir, the lineage behind them, legacy echoes,
## heirlooms, fate. All rules live here; the UI only calls methods and renders results.
class_name GameDynasty
extends RefCounted

static var save_path: String = "user://dynasty_save.json"
const JOURNAL_SAVED := 120   # journal lines a save keeps; the Chronicle shows the same span

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var dynasty_name: String = ""
var gen: int = 1
var heir: GameHeir
var state: String = "life"     # "life", "succession", or "ended" once the last generation's heir dies
var history: Array = []         # the founder and the latest dead heirs in full; older ones live in `ages`
var echoes: Array = []          # [{kind,key,text,strength,gen}]
var heirlooms: Array = []       # [{name, boss, gen}]
var slain_bosses: Dictionary = {}
var pending_archetype: String = ""
var candidates: Array = []      # Array[GameHeir] during succession
var last_death: Dictionary = {}
var journal: Array = []
var battle: GameBattle = null
var next_id: int = 1
var killer_id: String = ""
var total_hunts: int = 0
var world: GameWorld
var flags: Dictionary = {}      # story flags set by quests and events (flag -> generation set); never cleared
var quests := GameQuests.new()
var party := GameParty.new()
var pending_event: Dictionary = {}   # an event waiting for the player's choice (see GameEvents)
var shop_state: Dictionary = {}      # owned by GameItems: temple services used by the living heir
var ages := GameAges.new()           # per-Age summaries of older heirs, and the saga's greatest


static func new_game(p_seed: int, founder_name: String, class_id: String, bloodline_id: String, race_id: String = "human") -> GameDynasty:
	GameData.load_all()
	var d := GameDynasty.new()
	d.seed_value = p_seed
	d.rng.seed = p_seed
	var h := GameHeir.new()
	h.id = d._take_id()
	h.name = founder_name if founder_name != "" else GameInheritance.random_name(d.rng)
	h.surname = GameData.names["surnames"][d.rng.randi() % GameData.names["surnames"].size()]
	d.dynasty_name = h.surname
	h.class_id = class_id
	h.race_id = race_id
	h.traits = [bloodline_id]
	var others := GameData.traits_in(["bloodline"]).filter(func(t): return t != bloodline_id)
	h.dormant = [others[d.rng.randi() % others.size()]]
	d.world = GameWorld.create(d.rng)
	d._setup_new_heir(h)
	h.gold = int(GameData.bal("founder_gold"))
	d.heir = h
	d._say("The %s dynasty begins with %s, %s %s." % [d.dynasty_name, h.name, h.race()["name"], h.cls()["name"]])
	d._coming_of_age()
	return d


func _take_id() -> int:
	next_id += 1
	return next_id - 1


func _say(text: String) -> void:
	journal.append(text)
	if journal.size() > 300:
		journal = journal.slice(journal.size() - 300)


func _setup_new_heir(h: GameHeir) -> void:
	h.gen = gen
	h.age = h.adult_age()
	h.hazard_age = h.age
	h.level = 1
	h.xp = 0
	h.spells = []
	h.spell_news = []
	h.learn_spells()
	h.training = {"str": 0.0, "mag": 0.0, "agi": 0.0, "vit": 0.0}
	h.milestones_done = []
	h.battles_won = 0
	h.kills = {}
	h.children = []
	h.spouse = null
	h.family_founded = false
	h.extra_life_used = false
	h.potions = int(GameData.bal("start_potions"))
	h.heirloom_bonus = heirloom_bonus()
	h.lifespan = h.compute_lifespan()
	h.full_heal()


# ---------------------------------------------------------------- echoes / heirlooms

func heirloom_bonus() -> float:
	return float(mini(heirlooms.size(), int(GameData.bal("heirloom_max")))) * float(GameData.bal("heirloom_bonus"))


func echo_total(kind: String, key: String = "") -> float:
	var t := 0.0
	for e in echoes:
		if e["kind"] == kind and (key == "" or e["key"] == key):
			t += float(e["strength"])
	return t


func slayer_map() -> Dictionary:
	var m := {}
	for e in echoes:
		if e["kind"] == "slayer":
			m[e["key"]] = float(m.get(e["key"], 0.0)) + float(e["strength"])
	return m


func _add_echo(kind: String, key: String, text: String, strength: float) -> void:
	for e in echoes:
		if e["kind"] == kind and e["key"] == key:
			e["strength"] = snappedf(minf(1.0, float(e["strength"]) + strength), GameFate.STEP)  # echoes compound
			e["text"] = text
			e["gen"] = gen
			return
	echoes.append({"kind": kind, "key": key, "text": text, "strength": snappedf(strength, GameFate.STEP), "gen": gen})


func _decay_echoes() -> void:
	var decay := float(GameData.bal("echo_decay"))
	for e in echoes:
		e["strength"] = snappedf(float(e["strength"]) * decay, GameFate.STEP)
	echoes = echoes.filter(func(e): return float(e["strength"]) >= float(GameData.bal("echo_min_strength")))


func describe_echo(e: Dictionary) -> String:
	var pct := int(round(float(e["strength"]) * 100.0))
	match e["kind"]:
		"slayer":
			return "%s (+%d%% damage vs %s)" % [e["text"], pct, _creature_name(e["key"])]
		"glory":
			return "%s (+%d%% gold)" % [e["text"], pct]
		"infamy":
			return "%s (+%d%% shop prices)" % [e["text"], pct]
	return e["text"]


func _creature_name(id: String) -> String:
	for c in GameData.creatures:
		if c["id"] == id:
			return c["name"]
	return id


# ---------------------------------------------------------------- traits & fate

func _add_trait(h: GameHeir, id: String) -> bool:
	if id in h.traits:
		return false
	h.traits.append(id)
	h.dormant.erase(id)
	h.lifespan = h.compute_lifespan()
	return true


## "A bad omen at Coming of Age: you lose 40 gold and are Cursed." - with no gold, the loss is left out.
func _setback_text(what: String, label: String, loss: int, extra: String) -> String:
	if loss > 0:
		return "%s at %s: you lose %s gold%s." % [what, label, GameText.num(loss), " and " + extra if extra != "" else ""]
	if extra != "":
		return "%s at %s: you %s." % [what, label, extra]
	return "%s at %s, but there was no gold to lose." % [what, label]


func _check_milestone(milestone: String) -> void:
	if milestone in heir.milestones_done:
		return
	heir.milestones_done.append(milestone)
	var label: String = GameFate.MILESTONE_LABELS[milestone]
	if not GameFate.roll_failure(heir.fate_value, rng):
		_say("Milestone passed: %s." % label)
		return
	var sev := GameFate.roll_severity(heir.fate_value, rng)
	var msgs: Array = []
	match sev:
		"minor":
			var loss := int(float(heir.gold) * 0.2)
			heir.gold -= loss
			msgs.append(_setback_text("A minor setback", label, loss, ""))
		"moderate":
			var loss := int(float(heir.gold) * 0.4)
			heir.gold -= loss
			if rng.randf() < float(GameData.bal("moderate_curse_chance")):
				_add_trait(heir, "cursed")
				msgs.append(_setback_text("A bad omen", label, loss, "are Cursed"))
			else:
				msgs.append(_setback_text("A bad omen", label, loss, ""))
		"major":
			var loss := int(float(heir.gold) * 0.7)
			heir.gold -= loss
			var curse := ""
			if rng.randf() < float(GameData.bal("major_curse_chance")):
				curse = _random_new_curse(heir)
			msgs.append(_setback_text("A major failure", label, loss, "gain %s" % GameData.trait_name(curse) if curse != "" else ""))
			_add_echo("infamy", "major", "%s's failure is whispered about" % heir.name, 0.3)
		"critical":
			var curse := _random_new_curse(heir)
			_add_trait(heir, "scarred")
			var had_gold := heir.gold > 0
			heir.gold = int(float(heir.gold) * 0.2)
			heir.age += 5.0
			heir.hp = 1
			var hurt: Array = ["are gravely hurt", "age 5 years"]
			if had_gold:
				hurt.append("lose most of your wealth")
			if curse != "":
				hurt.append("gain " + GameData.trait_name(curse))
			msgs.append("DISASTER at %s! You %s and %s." % [label, ", ".join(hurt.slice(0, -1)), hurt[-1]])
			_add_echo("infamy", "critical", "%s's ruin became a cautionary tale" % heir.name, 0.5)
	pending_archetype = GameFate.roll_archetype(rng)
	msgs.append("Fate (%s): the next heir will be shaped by this: %s." % [sev, GameFate.ARCHETYPES[pending_archetype]["name"]])
	for m in msgs:
		_say(m)
	heir.hp = clampi(heir.hp, 1, heir.max_hp())


func _random_new_curse(h: GameHeir) -> String:
	var pool := GameData.traits_in(["curse"]).filter(func(t): return t not in h.traits)
	if pool.is_empty():
		return ""
	var id: String = pool[rng.randi() % pool.size()]
	_add_trait(h, id)
	return id


func _coming_of_age() -> void:
	heir.fate_value = GameFate.roll_fate_value(rng, heir.fate_modifier_total())
	_say("%s comes of age. Fate Value: %d%%." % [heir.name, int(round(heir.fate_value * 100.0))])
	_check_milestone("coming_of_age")


# ---------------------------------------------------------------- actions

func years_for(action: String) -> int:
	if action == "event":   # a fight an event led to; exploring already took its year
		return int(GameData.bal("event_fight_years"))
	return int(GameData.bal("years_per_action").get(action, 3))


func potion_price() -> int:
	var p := float(GameData.bal("potion_cost")) * GameData.enemy_scale(gen) * (1.0 + echo_total("infamy")) * (1.0 - GameItems.persuasion(self))
	return maxi(1, int(round(p)))


## The generation within the current Age (1..age_length): what every content window is read against.
func era_gen() -> int:
	return GameAges.era_of(gen)


func age_number() -> int:
	return GameAges.age_of(gen)


## Every heir who has died, kept in full or folded into an Age summary.
func ancestor_count() -> int:
	return history.size() + ages.folded_heirs()


## Legends stirring in this generation (not yet slain this Age), wherever their lair is.
func stirring_legends() -> Array:
	var era := era_gen()
	return GameData.creatures.filter(func(c): return c.get("boss", false) and c["min_gen"] <= era and era <= c["max_gen"] and not slain_bosses.has(c["id"]))


## The legend that can be challenged here: it must be stirring and this must be its lair.
func available_boss() -> Dictionary:
	for c in stirring_legends():
		if c.get("lair", world.location) == world.location:
			return c
	return {}


# ---------------------------------------------------------------- flags, items, events

func set_flag(flag: String, out: Variant = null) -> void:
	if not flags.has(flag):
		flags[flag] = gen
		quests.on_flag(self, flag, out)


func give_item(id: String) -> String:
	heir.inventory.append(id)
	return "%s received %s." % [heir.name, GameItems.item_def(id).get("name", id)]


func has_pending_event() -> bool:
	return not pending_event.is_empty()


func explore() -> Array:
	return GameEvents.explore(self)


func resolve_event(choice: int) -> Array:
	return GameEvents.resolve(self, choice)


# ---------------------------------------------------------------- travel & maps

func travel(to: String) -> Array:
	var link: Dictionary = {}
	for r in world.roads(world.location, flags):
		if r["to"] == to:
			link = r
	if link.is_empty():
		return ["There is no open road from %s to %s." % [world.here()["name"], GameWorld.place(to).get("name", to)]]
	var years := world.travel_years(link)
	var dest: Dictionary = GameWorld.place(to)
	var msgs: Array = []
	var slow := "" if float(world.weather().get("travel", 1.0)) <= 1.0 else " (slowed by %s)" % world.weather()["name"].to_lower()
	var first := to not in world.visited
	world.visit(to)
	msgs.append("%s travels to %s: %s%s." % [heir.name, dest["name"], _span_text(years), slow])
	if first:
		msgs.append("No one of House %s has walked %s before. %s" % [dynasty_name, dest["name"], dest.get("description", "")])
	quests.on_arrive(self, to, msgs)
	msgs = _pass_years(years, msgs)
	if state == "life":
		msgs.append_array(GameEvents.on_arrive(self, to))
	return msgs


func map_price(m: Dictionary) -> int:
	return maxi(1, int(round(float(m["price"]) * GameData.enemy_scale(gen))))


func buy_map(map_id: String) -> String:
	for m in world.maps_for_sale():
		if m["id"] == map_id:
			var price := map_price(m)
			if heir.gold < price:
				return "Not enough gold (%s needed)." % GameText.num(price)
			heir.gold -= price
			var n := world.chart(m["reveals"])
			return "Bought the %s for %s gold: %d new place%s charted." % [m["name"], GameText.num(price), n, "" if n == 1 else "s"]
	return "That map is not sold here."


static func _span_text(years: float) -> String:
	var seasons := int(round(years * 4.0))
	if seasons < 4:
		return "%d season%s" % [seasons, "" if seasons == 1 else "s"]
	return "%.1f years" % years


func can_found_family() -> bool:
	return not heir.family_founded and heir.age >= heir.family_min_age()


func can_retire() -> bool:
	return heir.family_founded or heir.age >= heir.midlife_age()


func buy_potion() -> String:
	var price := potion_price()
	if heir.gold < price:
		return "Not enough gold (%s needed)." % GameText.num(price)
	heir.gold -= price
	heir.potions += 1
	return "Bought a potion for %s gold." % GameText.num(price)


func rest() -> Array:
	heir.full_heal()
	party.rest(self)
	var msgs: Array = ["%s rests and recovers fully." % heir.name]
	GameDisease.on_rest(self, msgs)
	return _finish_time("rest", msgs)


func work() -> Array:
	var amount := float(GameData.bal("work_gold")) * GameData.enemy_scale(gen) * rng.randf_range(0.8, 1.2)
	amount *= 1.0 + heir.trait_total("work_gold") + heir.trait_total("theft") * 0.5 + echo_total("glory")
	var g := maxi(1, int(round(amount)))
	heir.gold += g
	return _finish_time("work", ["%s works odd jobs and earns %s gold." % [heir.name, GameText.num(g)]])


func train(stat: String) -> Array:
	heir.training[stat] += 1.5
	var msgs: Array = ["%s trains %s (+1.5 base)." % [heir.name, stat.to_upper()]]
	var lv := heir.gain_xp(int(round(float(GameData.bal("train_xp")) * GameData.xp_level_scale(heir.level))))
	if lv > 0:
		msgs.append("Level up! Now level %s." % GameText.num(heir.level))
	return _finish_time("train", msgs)


func found_family() -> Array:
	var msgs: Array = []
	if not can_found_family():
		return ["You cannot found a family right now."]
	var sp := GameHeir.new()
	sp.id = _take_id()
	sp.name = GameInheritance.random_name(rng)
	sp.surname = GameData.names["surnames"][rng.randi() % GameData.names["surnames"].size()]
	var class_ids := GameData.starting_ids(GameData.classes)
	sp.class_id = class_ids[rng.randi() % class_ids.size()]
	var race_ids := GameData.starting_ids(GameData.races)
	sp.race_id = heir.race_id if rng.randf() < float(GameData.bal("spouse_same_race_chance")) else race_ids[rng.randi() % race_ids.size()]
	var pool := GameData.traits_in(["bloodline", "blessing"]).filter(func(t): return t not in heir.traits)
	if rng.randf() < float(GameData.bal("spouse_trait_chance")) and not pool.is_empty():
		sp.traits.append(pool[rng.randi() % pool.size()])
	if rng.randf() < float(GameData.bal("spouse_trait_chance")) * 0.4 and not pool.is_empty():
		sp.dormant.append(pool[rng.randi() % pool.size()])
	sp.lifespan = sp.compute_lifespan()
	heir.spouse = sp
	var counts: Array = heir.race().get("children", [GameData.bal("child_count_min"), GameData.bal("child_count_max")])
	var n := rng.randi_range(int(counts[0]), int(counts[1]))
	for i in n:
		var res := GameInheritance.inherit([heir, sp], rng)
		var c := GameHeir.new()
		c.id = _take_id()
		c.name = GameInheritance.random_name(rng)
		c.surname = dynasty_name
		c.race_id = _child_race(heir.race_id, sp.race_id)
		c.class_id = _child_class(heir.class_id, sp.class_id)
		c.traits = res["traits"]
		c.dormant = res["dormant"]
		c.parent_names = [heir.name, sp.name]
		c.fate_value = GameFate.roll_fate_value(rng, c.fate_modifier_total())
		c.lifespan = c.compute_lifespan()
		heir.children.append(c)
		for ev in res["events"]:
			msgs.append("%s: %s" % [c.name, ev])
		msgs.append_array(GameDisease.on_birth(self, c))
	heir.family_founded = true
	msgs.push_front("%s marries %s, %s %s. %d child%s born." % [heir.name, sp.name, sp.race()["name"], sp.cls()["name"], n, "" if n == 1 else "ren"])
	_say(msgs[0])
	for i in range(1, msgs.size()):
		_say(msgs[i])
	_check_milestone("family_founded")
	return _finish_time("family", [])


## Parents of two different classes may raise a hybrid; otherwise a child usually follows a parent.
func _child_class(parent_class: String, other_class: String) -> String:
	var hybrid := GameData.hybrid_of(GameData.classes, parent_class, other_class)
	if hybrid != "" and rng.randf() < float(GameData.bal("hybrid_class_chance")):
		return hybrid
	var r := rng.randf()
	if r < 0.55:
		return parent_class
	if other_class != "" and r < 0.8:
		return other_class
	var ids := GameData.starting_ids(GameData.classes)
	return ids[rng.randi() % ids.size()]


func _child_race(a: String, b: String) -> String:
	if a == b:
		return a
	var hybrid := GameData.hybrid_of(GameData.races, a, b)
	if hybrid != "" and rng.randf() < float(GameData.bal("hybrid_race_chance")):
		return hybrid
	return a if rng.randf() < 0.5 else b


## Starts a hunt battle. kind: "hunt" or "hunt_hard".
func start_hunt(kind: String) -> GameBattle:
	var cfg: Dictionary = GameData.bal("hunt_rewards")[kind]
	var era := era_gen()
	var in_era := GameData.creatures.filter(func(c): return not c.get("boss", false) and c["min_gen"] <= era and era <= c["max_gen"])
	if in_era.is_empty():
		in_era = GameData.creatures.filter(func(c): return not c.get("boss", false))
	# Each place breeds its own monsters; if none of them roam in this era, anything in the era will do.
	var biomes: Array = world.here().get("biomes", [])
	var pool := in_era.filter(func(c): return (c.get("biomes", []) as Array).any(func(b): return b in biomes))
	if pool.is_empty():
		pool = in_era
	var danger := float(world.here().get("danger", 1.0))
	var n := rng.randi_range(int(cfg["min"]), int(cfg["max"]))
	var pack := GameCombat.roll_pack(self, kind, pool)   # sometimes a pack of weaker foes instead
	if not pack.is_empty():
		n = int(pack["size"])
	var foes: Array = []
	for i in n:
		# Monsters come in around the heir's level: usually a fair fight, sometimes a dangerous one.
		var lv_mult := rng.randf_range(float(cfg["level_min"]), float(cfg["level_max"])) * danger
		var elite := rng.randf() < float(cfg["elite_chance"]) * float(pack.get("elite", 1.0))
		if elite:
			lv_mult *= float(GameData.bal("elite_level_mult"))
		var kin: Dictionary = pack["creature"] if not pack.is_empty() else pool[rng.randi() % pool.size()]
		var foe := _make_enemy(kin, float(cfg["scale"]) * float(pack.get("power", 1.0)), float(cfg["reward"]) * float(pack.get("reward", 1.0)), maxi(1, int(round(float(heir.level) * lv_mult))))
		if elite:
			foe["name"] = "Elite " + foe["name"]
		foes.append(foe)
	return _begin_battle(foes, kind)


func start_legend() -> GameBattle:
	var boss := available_boss()
	if boss.is_empty():
		return null
	return _begin_battle([_make_enemy(boss, 1.0, 1.0, int(boss.get("min_level", 1)))], "legend")


var battle_kind: String = ""


func _begin_battle(foes: Array, kind: String) -> GameBattle:
	battle = GameBattle.new(heir, foes, rng)
	battle.slayer_bonus = slayer_map()
	battle.weather = world.weather().get("combat", {})
	battle.add_allies(party.battle_allies(self))
	battle_kind = kind
	_say("A battle begins: %s." % ", ".join(foes.map(func(e): return e["name"])))
	return battle


## Enemies are built at `level`: hunts match the heir's level, legends have a fixed one.
func _make_enemy(c: Dictionary, power: float, reward: float, level: int) -> Dictionary:
	var s := GameData.enemy_scale(gen) * power * GameData.enemy_level_scale(level)
	var hp := maxi(1, int(round(float(c["hp"]) * s)))
	return {
		"id": c["id"], "name": c["name"], "level": level, "hp": hp, "max_hp": hp,
		"atk": float(c["atk"]) * s, "def": float(c["defense"]) * s, "agi": c["agi"],
		"color": c["color"], "element": c.get("element", ""), "boss": c.get("boss", false),
		"xp": int(round(float(c["xp"]) * reward * GameData.xp_level_scale(level))),
		"gold": int(round(float(c["gold"]) * GameData.enemy_scale(gen) * reward)),
		"heirloom": c.get("heirloom", ""), "bonus": c.get("bonus", 0.0),
	}


## Apply the outcome of a finished battle. Returns messages to show.
func finish_battle() -> Array:
	var b := battle
	battle = null
	var msgs: Array = []
	if b == null:
		return msgs
	var party_msgs := party.after_battle(self, b)
	match b.result:
		"victory":
			var xp := 0
			var gold := 0
			var quest_msgs: Array = []
			for e in b.enemies:
				xp += int(e["xp"])
				gold += int(e["gold"])
				heir.kills[e["id"]] = int(heir.kills.get(e["id"], 0)) + 1
				quests.on_kill(self, e["id"], quest_msgs)
				if e["boss"] and not slain_bosses.has(e["id"]):
					slain_bosses[e["id"]] = gen
					# A legend risen again in a later Age leaves no second copy of its heirloom.
					if heirlooms.any(func(x): return x["name"] == e["heirloom"]):
						msgs.append(GameAges.text("heirloom_held", {"heirloom": e["heirloom"], "house": dynasty_name}))
					elif e["heirloom"] != "":
						heirlooms.append({"name": e["heirloom"], "boss": e["name"], "gen": gen})
						heir.heirloom_bonus = heirloom_bonus()
						msgs.append("Heirloom claimed: %s! (+%d%% power for all descendants)" % [e["heirloom"], int(float(GameData.bal("heirloom_bonus")) * 100.0)])
					_add_echo("slayer", e["id"], "%s slew %s" % [heir.name, e["name"]], 0.25)
					msgs.append("Legend: %s has slain %s." % [heir.name, e["name"]])
			gold = int(round(float(gold) * (1.0 + heir.trait_total("luck") + heir.trait_total("theft") * 0.3 + echo_total("glory"))))
			heir.gold += gold
			heir.battles_won += 1
			total_hunts += 1
			msgs.append("Victory! +%s XP, +%s gold." % [GameText.num(xp), GameText.num(gold)])
			if heir.gain_xp(xp) > 0:
				msgs.append("Level up! %s is now level %s." % [heir.name, GameText.num(heir.level)])
			msgs.append_array(quest_msgs)
			msgs.append_array(party_msgs)
			for m in msgs:
				_say(m)
			_check_milestone("first_quest")
			msgs.append_array(_finish_time(battle_kind, []))
		"fled":
			msgs.append("%s flees from the battle." % heir.name)
			msgs.append_array(party_msgs)
			for m in msgs:
				_say(m)
			msgs.append_array(_finish_time("rest", []))
		"defeat":
			killer_id = ""
			for e in b.enemies:
				if e["hp"] > 0:
					killer_id = e["id"]
					break
			if heir.trait_total("extra_life") > 0.0 and not heir.extra_life_used:
				heir.extra_life_used = true
				heir.hp = heir.max_hp()
				msgs.append("Death refuses %s! Marked by Death, they rise again at full health." % heir.name)
				msgs.append_array(party_msgs)
				for m in msgs:
					_say(m)
				msgs.append_array(_finish_time(battle_kind, []))
			elif rng.randf() < float(GameData.bal("death_chance_on_defeat")):
				msgs.append("%s was slain in battle." % heir.name)
				msgs.append_array(party_msgs)
				for m in msgs:
					_say(m)
				msgs.append_array(_die("slain in battle"))
			else:
				var loss := int(float(heir.gold) * float(GameData.bal("defeat_gold_loss")))
				heir.gold -= loss
				heir.hp = 1
				heir.mp = 0
				heir.age += float(GameData.bal("defeat_years"))
				msgs.append("%s is dragged from the field, barely alive. Lost %s gold." % [heir.name, GameText.num(loss)])
				msgs.append_array(party_msgs)
				for m in msgs:
					_say(m)
				msgs.append_array(_finish_time(battle_kind, []))
		_:
			msgs.append_array(party_msgs)
			for m in msgs:
				_say(m)
	return msgs


func _finish_time(action: String, msgs: Array) -> Array:
	return _pass_years(float(years_for(action)), msgs)


## Time passes for the heir and the world: ageing, milestones, weather, death of old age.
func _pass_years(years: float, msgs: Array) -> Array:
	for m in msgs:
		_say(m)
	if state != "life":
		return msgs
	if not heir.spell_news.is_empty():
		var learned := "%s learns to cast %s." % [heir.name, " and ".join(heir.spell_news.map(func(id): return GameCombat.spell(id).get("name", id)))]
		heir.spell_news = []
		msgs.append(learned)
		_say(learned)
	heir.age += years
	world.advance(years, rng)
	party.on_years(self, years, msgs)
	heir.mp = mini(heir.max_mp(), heir.mp + int(ceil(float(heir.max_mp()) * 0.1)))
	if heir.age >= heir.midlife_age():
		_check_milestone("midlife")
	if heir.age >= heir.lifespan * float(GameData.bal("elder_fraction")):
		_check_milestone("elder_years")
	GameDisease.on_years(self, years, msgs)
	# Covers every year since the last roll, including years lost to defeats and disasters.
	var dies := rng.randf() < heir.old_age_death_chance(heir.hazard_age, heir.age)
	heir.hazard_age = heir.age
	if state == "life" and dies:
		var dm := _die("old age")
		for m in dm:
			msgs.append(m)
	return msgs


func retire() -> Array:
	if not can_retire():
		return ["It is too soon to retire."]
	_say("%s retires from adventuring." % heir.name)
	return _die("old age")


# ---------------------------------------------------------------- death & succession

func _die(cause: String) -> Array:
	var msgs: Array = []
	var rec := {
		"gen": gen, "name": heir.full_name(), "class_id": heir.class_id, "race_id": heir.race_id,
		"traits": heir.traits.map(func(t): return GameData.trait_name(t)),
		"level": heir.level, "age": int(heir.age), "cause": cause, "gold": heir.gold,
		"battles_won": heir.battles_won, "kills": heir.kills.duplicate(),
		"parents": heir.parent_names.duplicate(), "archetype": heir.archetype,
		"children": heir.children.map(func(c): return c.name),
		"spouse": heir.spouse.name if heir.spouse != null else "",
	}
	history.append(rec)
	ages.on_death(self, rec)
	msgs.append("%s dies of %s at age %d." % [heir.name, cause, int(heir.age)] if cause == "old age" else "%s dies: %s, at age %d." % [heir.name, cause, int(heir.age)])
	if cause == "slain in battle":
		if killer_id != "":
			_add_echo("slayer", killer_id, "%s fell to %s" % [heir.name, _creature_name(killer_id)], 0.15)
	elif heir.level >= glory_level(heir):
		var strength := 0.1 * float(heir.level) / glory_level(heir)
		_add_echo("glory", "life", "%s lived a celebrated life" % heir.name, clampf(strength, 0.0, 0.2))
	if gen >= GameAges.max_generations():
		last_death = rec
		GameAges.end_saga(self, msgs)
		for m in msgs:
			_say(m)
		return msgs
	var kids: Array = heir.children
	if kids.is_empty():
		msgs.append("%s left no children. Distant cousins step forward." % heir.name)
		kids = _cousins()
	candidates = kids
	state = "succession"
	last_death = rec
	for m in msgs:
		_say(m)
	return msgs


## Level needed for a "celebrated life"; longer-lived heirs must reach higher.
func glory_level(h: GameHeir) -> float:
	var span_ratio := maxf(1.0, h.lifespan / float(GameData.bal("glory_reference_lifespan")))
	return float(GameData.bal("glory_min_level")) * pow(span_ratio, 0.7)


func _cousins() -> Array:
	var out: Array = []
	for i in 2:
		var res := GameInheritance.inherit([heir], rng, float(GameData.bal("adopted_inherit_penalty")))
		var c := GameHeir.new()
		c.id = _take_id()
		c.name = GameInheritance.random_name(rng)
		c.surname = dynasty_name
		c.race_id = heir.race_id
		c.class_id = _child_class(heir.class_id, "")
		c.traits = res["traits"]
		c.dormant = res["dormant"]
		c.parent_names = ["(distant cousin of %s)" % heir.name]
		c.fate_value = GameFate.roll_fate_value(rng, c.fate_modifier_total())
		c.lifespan = c.compute_lifespan()
		out.append(c)
	return out


## Pick the next heir from `candidates`. Applies fate archetype, gold inheritance, echo decay.
func choose_heir(index: int) -> Array:
	var msgs: Array = []
	if state != "succession" or index < 0 or index >= candidates.size():
		return msgs
	var parent := heir
	var c: GameHeir = candidates[index]
	gen += 1
	if era_gen() == 1:
		GameAges.begin_age(self, msgs)
	_decay_echoes()
	c.archetype = pending_archetype
	c.archetype_bonus = {}
	if pending_archetype != "":
		var a: Dictionary = GameFate.ARCHETYPES[pending_archetype]
		c.archetype_bonus = a["bonus"].duplicate()
		msgs.append("%s is a %s. %s" % [c.name, a["name"], a["desc"]])
		if pending_archetype == "rebel":
			var ids := GameData.starting_ids(GameData.classes).filter(func(x): return x != parent.class_id)
			c.class_id = ids[rng.randi() % ids.size()]
			msgs.append("%s rejects the family trade and becomes a %s." % [c.name, c.cls()["name"]])
		if pending_archetype == "redeemer":
			for t in c.traits:
				if GameData.trait_def(t).get("category", "") == "curse":
					c.traits.erase(t)
					c.dormant.append(t)
					msgs.append("%s shed the burden of %s (now dormant)." % [c.name, GameData.trait_name(t)])
					break
	pending_archetype = ""
	world.visit(GameData.world["start"])
	_setup_new_heir(c)
	# The heir inherits what the family has left: its gold and the items bought.
	c.gold = int(float(parent.gold) * float(GameData.bal("gold_inherit_fraction")))
	c.potions = maxi(c.potions, parent.potions)
	var bonus_gold: int = int(GameFate.ARCHETYPES.get(c.archetype, {}).get("gold", 0))
	if bonus_gold > 0:
		c.gold += int(float(bonus_gold) * GameData.enemy_scale(gen))
	# Gear and carried items pass down with the house.
	c.equipment = parent.equipment.duplicate()
	c.inventory = parent.inventory.duplicate()
	GameDisease.on_succession(self, parent, c, msgs)
	c.refresh_derived()
	c.full_heal()
	heir = c
	party.on_succession(self, msgs)
	quests.on_succession(self, msgs)
	candidates = []
	state = "life"
	_say("Generation %s: %s takes up the family name." % [GameText.num(gen), c.full_name()])
	if gen == GameAges.max_generations():
		msgs.append(GameAges.text("last_heir", {"heir": c.name, "house": dynasty_name}))
	for m in msgs:
		_say(m)
	# Re-roll nothing: fate value was rolled at birth. Run the first milestone.
	_check_milestone("coming_of_age")
	_say("Inherited %s gold." % GameText.num(c.gold))
	return msgs


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	return {
		"version": 1, "seed": seed_value, "rng_state": str(rng.state), "dynasty_name": dynasty_name,
		"gen": gen, "heir": heir.to_dict(), "state": state, "history": history, "echoes": echoes,
		"heirlooms": heirlooms, "slain_bosses": slain_bosses, "pending_archetype": pending_archetype,
		"candidates": candidates.map(func(c): return c.to_dict()), "last_death": last_death,
		"journal": journal.slice(maxi(0, journal.size() - JOURNAL_SAVED)), "next_id": next_id, "total_hunts": total_hunts,
		"killer_id": killer_id, "world": world.to_dict(), "flags": flags,
		"quests": quests.to_dict(), "party": party.to_dict(), "pending_event": pending_event,
		"shop_state": shop_state, "ages": ages.to_dict(),
	}


static func from_dict(d: Dictionary) -> GameDynasty:
	GameData.load_all()
	var g := GameDynasty.new()
	g.seed_value = int(d["seed"])
	g.rng.seed = g.seed_value
	g.rng.state = int(d["rng_state"])
	g.dynasty_name = d["dynasty_name"]
	g.gen = int(d["gen"])
	g.heir = GameHeir.from_dict(d["heir"])
	g.state = d["state"]
	g.history = _ints(Array(d["history"]))
	g.ages = GameAges.from_dict(d.get("ages"), g)
	g.echoes = Array(d["echoes"])
	for e in g.echoes:
		e["gen"] = int(e["gen"])
		e["strength"] = snappedf(float(e["strength"]), GameFate.STEP)
	g.heirlooms = _ints(Array(d["heirlooms"]))
	g.slain_bosses = _ints(d["slain_bosses"])
	GameAges.wake_legends(g)
	g.heir.heirloom_bonus = g.heirloom_bonus()
	g.pending_archetype = d["pending_archetype"]
	for c in d["candidates"]:
		g.candidates.append(GameHeir.from_dict(c))
	g.last_death = _ints(d["last_death"])
	g.journal = Array(d["journal"])
	g.next_id = int(d["next_id"])
	g.total_hunts = int(d["total_hunts"])
	g.killer_id = d.get("killer_id", "")
	g.world = GameWorld.from_dict(d["world"]) if d.has("world") else GameWorld.create(g.rng)
	g.flags = _ints(d.get("flags", {}))
	g.quests = GameQuests.from_dict(d.get("quests", {}))
	g.party = GameParty.from_dict(d.get("party", {}), g)
	g.pending_event = _ints(d.get("pending_event", {}))
	g.shop_state = _ints(d.get("shop_state", {}))
	if g.state == "succession" and g.gen >= GameAges.max_generations():   # no heir is chosen past the last generation
		GameAges.end_saga(g, [])
	return g


## JSON parsing turns every number into a float; restore whole numbers to ints.
static func _ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) else v
		TYPE_ARRAY:
			return (v as Array).map(func(x): return _ints(x))
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _ints(v[k])
			return out
	return v


func save_to_disk() -> bool:
	if battle != null:
		return false
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func load_from_disk() -> GameDynasty:
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_dict(parsed)
