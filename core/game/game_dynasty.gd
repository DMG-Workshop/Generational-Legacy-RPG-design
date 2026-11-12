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
var clock_carry: float = 0.0    # years the world clock has been fed but not yet lived through (see GameClock); saved only when above 0
var world_seconds: float = 0.0  # seconds the world clock has run, the day follows from it (see GameDay); saved only when above 0
var house_titles: Array = []    # ids of the house titles the dynasty has earned (see GameTitles); saved only once there is one
var achievements: Dictionary = {}   # milestones the house has reached, id -> {gen, year, heir} (see GameAchievements); saved only once there is one
var hard: Dictionary = {}       # hard-mode options chosen at the founding (see GameHardMode); saved only when one is on
var world_event: Dictionary = {}    # the war, famine or golden age running now, or the rest after one (see GameWorldEvents); saved only when not empty
var house: Dictionary = {}      # the family house: track -> level bought (see GameHouse); the dynasty keeps it across heirs
var slain_bosses: Dictionary = {}
var pending_archetype: String = ""
var candidates: Array = []      # Array[GameHeir] during succession
var last_death: Dictionary = {}
var journal: Array = []
var battle: GameBattle = null
var next_id: int = 1
var killer_id: String = ""
var total_hunts: int = 0
var roster: Array = []          # eggs and young the family keeps (see GameRoster); saved only when not empty
var mine: Dictionary = {}       # the ground dug at each site, its strain and its gateways (see GameMine); saved only when not empty
var built: Dictionary = {}      # the pieces the family has built, {"x,y,z": kind} (see GameBuild); saved only when not empty
var gathered: Dictionary = {}   # nodes companions have gathered, {"x,z": world year} (see GameCompanions); saved only when not empty
var stores: Dictionary = {}     # materials and essences the family has gathered, and how many pieces it has made (see GameCraft); saved only when not empty
var world: GameWorld
var flags: Dictionary = {}      # story flags set by quests and events (flag -> generation set); never cleared
var quests := GameQuests.new()
var party := GameParty.new()
var pending_event: Dictionary = {}   # an event waiting for the player's choice (see GameEvents)
var shop_state: Dictionary = {}      # owned by GameItems: temple services used by the living heir
var ages := GameAges.new()           # per-Age summaries of older heirs, and the saga's greatest
var auto_battle: bool = false        # the player's choice: hunts fight themselves (see GameTactics.auto_turn)
var loot: Dictionary = {}            # the dead of the last victory, until searched or left (see GamePlague)
var auto_party: Dictionary = {}      # the player's Auto switches for party command rounds: {heir?, companion_default?} (see GameRound)
var command_round: GameRound = null  # the battle's command round, made on first use (see battle_round)


static func new_game(p_seed: int, founder_name: String, class_id: String, bloodline_id: String, race_id: String = "human", p_sex: String = GameSex.MALE, p_subclass: String = "", p_hard: Dictionary = {}) -> GameDynasty:
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
	h.sex = p_sex if GameSex.valid(p_sex) else GameSex.MALE
	h.traits = [bloodline_id]
	GameSubclass.found(h, p_subclass)   # none unless one was chosen at the founding
	var others := GameData.traits_in(["bloodline"]).filter(func(t): return t != bloodline_id)
	h.dormant = [others[d.rng.randi() % others.size()]]
	d.world = GameWorld.create(d.rng)
	d._setup_new_heir(h)
	h.gold = int(GameData.bal("founder_gold"))
	d.heir = h
	d._say(GameMessages.text("life", "dynasty_begins", {"dynasty": d.dynasty_name, "heir": h.name, "race": h.race()["name"], "cls": h.cls()["name"]}))
	d._coming_of_age()
	if not p_hard.is_empty():   # hard-mode options are chosen here or never (choices the rules refuse found a plain house)
		GameHardMode.found(d, p_hard)
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
	GameFeats.start(h)
	GameSkillTree.start(h)
	h.training = {"str": 0.0, "mag": 0.0, "agi": 0.0, "vit": 0.0}
	h.milestones_done = []
	h.battles_won = 0
	h.clean_streak = 0
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
	return GameHeirlooms.total_bonus(self)   # each heirloom's base and its levels (item 18); with no levels, exactly count times heirloom_bonus


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
			return GameMessages.text("life", "echo_damage_vs", {"text": e["text"], "pct": int(pct), "foe": _creature_name(e["key"])})
		"glory":
			return GameMessages.text("life", "echo_gold", {"text": e["text"], "pct": int(pct)})
		"infamy":
			return GameMessages.text("life", "echo_shop", {"text": e["text"], "pct": int(pct)})
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
	if loss > 0 and extra != "":
		return GameMessages.text("life", "setback_loss_extra", {"what": what, "label": label, "loss": GameText.num(loss), "extra": extra})
	if loss > 0:
		return GameMessages.text("life", "setback_loss", {"what": what, "label": label, "loss": GameText.num(loss)})
	if extra != "":
		return GameMessages.text("life", "setback_extra", {"what": what, "label": label, "extra": extra})
	return GameMessages.text("life", "setback_none", {"what": what, "label": label})


## The name of a setback's severity, as the fate line shows it.
func _severity_text(sev: String) -> String:
	match sev:
		"minor":
			return GameMessages.text("life", "sev_minor")
		"moderate":
			return GameMessages.text("life", "sev_moderate")
		"major":
			return GameMessages.text("life", "sev_major")
		"critical":
			return GameMessages.text("life", "sev_critical")
	return sev


## How a death's cause reads in the message; a cause the catalog does not name is shown as it is.
func _cause_text(cause: String) -> String:
	if cause == "slain in battle":
		return GameMessages.text("life", "cause_slain")
	return cause


func _check_milestone(milestone: String) -> void:
	if milestone in heir.milestones_done:
		return
	heir.milestones_done.append(milestone)
	var label: String = GameFate.milestone_label(milestone)
	if not GameFate.roll_failure(heir.fate_value, rng):
		_say(GameMessages.text("life", "milestone_passed", {"label": label}))
		return
	var sev := GameFate.roll_severity(heir.fate_value, rng)
	var msgs: Array = []
	match sev:
		"minor":
			var loss := int(float(heir.gold) * 0.2)
			heir.gold -= loss
			msgs.append(_setback_text(GameMessages.text("life", "what_minor"), label, loss, ""))
		"moderate":
			var loss := int(float(heir.gold) * 0.4)
			heir.gold -= loss
			if rng.randf() < float(GameData.bal("moderate_curse_chance")):
				_add_trait(heir, "cursed")
				msgs.append(_setback_text(GameMessages.text("life", "what_omen"), label, loss, GameMessages.text("life", "omen_cursed")))
			else:
				msgs.append(_setback_text(GameMessages.text("life", "what_omen"), label, loss, ""))
		"major":
			var loss := int(float(heir.gold) * 0.7)
			heir.gold -= loss
			var curse := ""
			if rng.randf() < float(GameData.bal("major_curse_chance")):
				curse = _random_new_curse(heir)
			msgs.append(_setback_text(GameMessages.text("life", "what_major"), label, loss, GameMessages.text("life", "gain_trait", {"trait": GameData.trait_name(curse)}) if curse != "" else ""))
			_add_echo("infamy", "major", GameMessages.text("life", "echo_whispered", {"name": heir.name}), 0.3)
		"critical":
			var curse := _random_new_curse(heir)
			_add_trait(heir, "scarred")
			var had_gold := heir.gold > 0
			heir.gold = int(float(heir.gold) * 0.2)
			heir.age += 5.0
			heir.hp = 1
			var hurt: Array = [GameMessages.text("life", "hurt_gravely"), GameMessages.text("life", "hurt_age")]
			if had_gold:
				hurt.append(GameMessages.text("life", "hurt_wealth"))
			if curse != "":
				hurt.append(GameMessages.text("life", "gain_trait", {"trait": GameData.trait_name(curse)}))
			msgs.append(GameMessages.text("life", "disaster", {"label": label, "hurt": GameMessages.text("life", "list_comma").join(hurt.slice(0, -1)), "last": hurt[-1]}))
			_add_echo("infamy", "critical", GameMessages.text("life", "echo_ruin", {"name": heir.name}), 0.5)
	pending_archetype = GameFate.roll_archetype(rng)
	msgs.append(GameMessages.text("life", "fate_next", {"sev": _severity_text(sev), "archetype": GameFate.archetype_name(pending_archetype)}))
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
	_say(GameMessages.text("life", "comes_of_age", {"name": heir.name, "fate": int(int(round(heir.fate_value * 100.0)))}))
	_check_milestone("coming_of_age")


# ---------------------------------------------------------------- actions

func years_for(action: String) -> int:
	if action == "event":   # a fight an event led to; exploring already took its year
		return int(GameData.bal("event_fight_years"))
	return int(GameData.bal("years_per_action").get(action, 3))


func potion_price() -> int:
	var p := float(GameData.bal("potion_cost")) * GameData.enemy_scale(gen) * (1.0 + echo_total("infamy")) * (1.0 - GameItems.persuasion(self)) * GameWorldEvents.mult(self, "price_mult")
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
	return GameMessages.text("life", "received_item", {"name": heir.name, "item": GameItems.item_def(id).get("name", id)})


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
		return [GameMessages.text("life", "no_open_road", {"here": world.here()["name"], "there": GameWorld.place(to).get("name", to)})]
	var years := world.travel_years(link)
	var dest: Dictionary = GameWorld.place(to)
	var msgs: Array = []
	var slow := "" if float(world.weather().get("travel", 1.0)) <= 1.0 else GameMessages.text("life", "slowed", {"weather": world.weather()["name"].to_lower()})
	var first := to not in world.visited
	world.visit(to)
	msgs.append(GameMessages.text("life", "travels", {"name": heir.name, "dest": dest["name"], "span": _span_text(years), "slow": slow}))
	if first:
		msgs.append(GameMessages.text("life", "no_one_walked", {"house": dynasty_name, "dest": dest["name"], "description": dest.get("description", "")}))
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
				return GameMessages.text("life", "not_enough_gold", {"needed": GameText.num(price)})
			heir.gold -= price
			var n := world.chart(m["reveals"])
			return GameMessages.text("life", "bought_map", {"item": m["name"], "price": GameText.num(price), "places": GameMessages.text("life", "places_one" if n == 1 else "places_many", {"n": int(n)})})
	return GameMessages.text("life", "map_not_sold")


static func _span_text(years: float) -> String:
	var seasons := int(round(years * 4.0))
	if seasons < 4:
		return GameMessages.text("life", "seasons_one" if seasons == 1 else "seasons_many", {"n": int(seasons)})
	return GameMessages.text("life", "years_fmt", {"years": ("%.1f" % [years])})


func can_found_family() -> bool:
	return not heir.family_founded and heir.age >= heir.family_min_age()


func can_retire() -> bool:
	return heir.family_founded or heir.age >= heir.midlife_age()


## Dresses the heir (by -1) or a companion (their place in the party) in a shirt colour from
## data/art/shirts.json; "" gives back the one picked for them. Only the look changes: nothing is rolled.
func set_shirt(by: int, shirt_id: String) -> void:
	if by < 0:
		heir.shirt = shirt_id
	elif by < party.members.size():
		if shirt_id == "":
			party.members[by].erase("shirt")
		else:
			party.members[by]["shirt"] = shirt_id


## The shirt colour chosen for the heir (by -1) or a companion; "" when none is.
func shirt_of(by: int) -> String:
	if by < 0:
		return heir.shirt
	if by < party.members.size():
		var v = party.members[by].get("shirt", "")
		return str(v) if typeof(v) == TYPE_STRING else ""
	return ""


func buy_potion() -> String:
	var price := potion_price()
	if heir.gold < price:
		return GameMessages.text("life", "not_enough_gold", {"needed": GameText.num(price)})
	heir.gold -= price
	heir.potions += 1
	return GameMessages.text("life", "bought_potion", {"price": GameText.num(price)})


func rest() -> Array:
	heir.full_heal()
	party.rest(self)
	var msgs: Array = [GameMessages.text("life", "rests", {"name": heir.name})]
	GameDisease.on_rest(self, msgs)
	msgs = _finish_time("rest", msgs)
	heir.downtime = state == "life"   # until the next action that takes time (see GameFeats)
	return msgs


func work() -> Array:
	var amount := float(GameData.bal("work_gold")) * GameData.enemy_scale(gen) * rng.randf_range(0.8, 1.2)
	amount *= 1.0 + heir.trait_total("work_gold") + heir.trait_total("theft") * 0.5 + echo_total("glory")
	amount *= GameWorldEvents.mult(self, "work_gold_mult")
	var g := maxi(1, int(round(amount)))
	heir.gold += g
	return _finish_time("work", [GameMessages.text("life", "works_odd_jobs", {"name": heir.name, "gold": GameText.num(g)})])


func train(stat: String) -> Array:
	heir.training[stat] += 1.5
	var msgs: Array = [GameMessages.text("life", "trains", {"name": heir.name, "stat": stat.to_upper()})]
	var lv := heir.gain_xp(int(round(float(GameData.bal("train_xp")) * GameData.xp_level_scale(heir.level) * GameHouse.train_xp_mult(self))))
	if lv > 0:
		msgs.append(GameMessages.text("life", "level_up_now", {"level": GameText.num(heir.level)}))
	return _finish_time("train", msgs)


## The mates the heir can marry: opposite-sex candidates, drawn from their own seeded dice (not the main
## dice), so looking at them changes nothing. Ids are placeholders until one is chosen.
func mate_candidates() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, heir.id, gen, "mates"])
	var out: Array = []
	for i in int(GameData.bal("mate_candidate_count")):
		out.append(_make_mate(r, -(i + 1)))
	return out


func _make_mate(r: RandomNumberGenerator, id: int) -> GameHeir:
	var sp := GameHeir.new()
	sp.id = id
	sp.sex = GameSex.opposite(heir.sex)   # mates are always the opposite sex
	sp.name = GameInheritance.random_name(r)
	sp.surname = GameData.names["surnames"][r.randi() % GameData.names["surnames"].size()]
	var class_ids := GameData.starting_ids(GameData.classes)
	sp.class_id = class_ids[r.randi() % class_ids.size()]
	var race_ids := GameData.starting_ids(GameData.races)
	sp.race_id = heir.race_id if r.randf() < float(GameData.bal("spouse_same_race_chance")) else race_ids[r.randi() % race_ids.size()]
	var pool := GameData.traits_in(["bloodline", "blessing"]).filter(func(t): return t not in heir.traits)
	if r.randf() < float(GameData.bal("spouse_trait_chance")) and not pool.is_empty():
		sp.traits.append(pool[r.randi() % pool.size()])
	if r.randf() < float(GameData.bal("spouse_trait_chance")) * 0.4 and not pool.is_empty():
		sp.dormant.append(pool[r.randi() % pool.size()])
	sp.lifespan = sp.compute_lifespan()
	return sp


## Founds the family. `mate` picks one of mate_candidates(); -1 keeps the old random spouse.
func found_family(mate: int = -1) -> Array:
	var msgs: Array = []
	if not can_found_family():
		return [GameMessages.text("life", "cannot_found")]
	var mates := mate_candidates()
	var sp: GameHeir
	if mate >= 0 and mate < mates.size():
		sp = mates[mate]
		sp.id = _take_id()
	else:
		sp = GameHeir.new()
		sp.id = _take_id()
		sp.sex = GameSex.opposite(heir.sex)   # mates are always the opposite sex
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
		c.sex = GameSex.roll(seed_value, c.id)
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
			msgs.append(GameMessages.text("life", "child_event", {"name": c.name, "event": ev}))
		msgs.append_array(GameDisease.on_birth(self, c))
	heir.family_founded = true
	msgs.push_front(GameMessages.text("life", "marries", {"heir": heir.name, "spouse": sp.name, "race": sp.race()["name"], "cls": sp.cls()["name"], "children": GameMessages.text("life", "child_born_one" if n == 1 else "children_born", {"n": int(n)})}))
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


## The battle's party command round (see GameRound), made when first asked for and dropped with the
## battle. Autopilots never ask for it.
func battle_round() -> GameRound:
	if battle == null:
		return null
	if command_round == null or command_round.b != battle:
		command_round = GameRound.open(battle, auto_party, party)
	return command_round


## Starts a hunt battle. kind: "hunt" or "hunt_hard".
func start_hunt(kind: String) -> GameBattle:
	var cfg: Dictionary = GameData.bal("hunt_rewards")[kind]
	# Each place breeds its own monsters; if none of them roam in this era, anything in the era will do (GameSpawn.hunt_pool).
	var pool := GameSpawn.hunt_pool(era_gen(), world.here().get("biomes", []))
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
			foe["name"] = GameMessages.text("life", "elite_name", {"name": foe["name"]})
		foes.append(foe)
	return _begin_battle(foes, kind)


func start_legend() -> GameBattle:
	var boss := available_boss()
	if boss.is_empty():
		return null
	return _begin_battle([_make_enemy(boss, 1.0, 1.0, int(boss.get("min_level", 1)))], "legend")


var battle_kind: String = ""


func _begin_battle(foes: Array, kind: String) -> GameBattle:
	loot = {}
	if kind != "legend":
		GamePlague.mark_infected(self, foes)
	battle = GameBattle.new(heir, foes, rng)
	battle.slayer_bonus = slayer_map()
	battle.weather = world.weather().get("combat", {})
	battle.biomes = world.here().get("biomes", [])
	battle.add_allies(party.battle_allies(self))
	battle.open_with_breath()
	battle_kind = kind
	_say(GameMessages.text("life", "battle_begins", {"foes": GameMessages.text("life", "list_comma").join(foes.map(func(e): return e["name"]))}))
	return battle


## Enemies are built at `level`: hunts match the heir's level, legends have a fixed one.
func _make_enemy(c: Dictionary, power: float, reward: float, level: int) -> Dictionary:
	var s := GameData.enemy_scale(gen) * power * GameData.enemy_level_scale(level)
	var hp := maxi(1, int(round(float(c["hp"]) * s)))
	return {
		"id": c["id"], "name": c["name"], "level": level, "hp": hp, "max_hp": hp,
		"atk": float(c["atk"]) * s, "def": float(c["defense"]) * s, "agi": c["agi"],
		"color": c["color"], "element": c.get("element", ""), "tags": c.get("tags", []), "boss": c.get("boss", false),
		"xp": int(round(float(c["xp"]) * reward * GameData.xp_level_scale(level))),
		"gold": int(round(float(c["gold"]) * GameData.enemy_scale(gen) * reward)),
		"heirloom": c.get("heirloom", ""), "bonus": c.get("bonus", 0.0),
	}


## Apply the outcome of a finished battle. Returns messages to show.
func finish_battle() -> Array:
	var b := battle
	battle = null
	command_round = null
	var msgs: Array = []
	if b == null:
		return msgs
	var party_msgs := party.after_battle(self, b)
	party_msgs.append_array(GamePlague.after_battle(self, b))
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
						msgs.append(GameMessages.text("life", "heirloom_claimed", {"heirloom": e["heirloom"], "pct": int(int(float(GameData.bal("heirloom_bonus")) * 100.0))}))
					_add_echo("slayer", e["id"], GameMessages.text("life", "echo_slew", {"name": heir.name, "foe": e["name"]}), 0.25)
					msgs.append(GameMessages.text("life", "legend_slain", {"name": heir.name, "foe": e["name"]}))
			gold = int(round(float(gold) * (1.0 + heir.trait_total("luck") + heir.trait_total("theft") * 0.3 + echo_total("glory")) * GameWorldEvents.mult(self, "hunt_gold_mult")))
			if GameWorldEvents.mult(self, "hunt_xp_mult") != 1.0:
				xp = int(round(float(xp) * GameWorldEvents.mult(self, "hunt_xp_mult")))
			heir.gold += gold
			heir.battles_won += 1
			# A win that left the heir barely scratched adds to the clean run; a costly one ends it.
			if float(heir.hp) >= float(GameData.bal("bot_hard_hunt")["clean_hp_frac"]) * float(heir.max_hp()):
				heir.clean_streak += 1
			else:
				heir.clean_streak = 0
			total_hunts += 1
			msgs.append(GameMessages.text("life", "victory", {"xp": GameText.num(xp), "gold": GameText.num(gold)}))
			if heir.gain_xp(xp) > 0:
				msgs.append(GameMessages.text("life", "level_up_named", {"name": heir.name, "level": GameText.num(heir.level)}))
			msgs.append_array(quest_msgs)
			msgs.append_array(party_msgs)
			for m in msgs:
				_say(m)
			_check_milestone("first_quest")
			msgs.append_array(_finish_time(battle_kind, []))
			if state == "life":
				loot = GamePlague.offer(self, b)
		"fled":
			heir.clean_streak = 0
			msgs.append(GameMessages.text("life", "flees", {"name": heir.name}))
			msgs.append_array(party_msgs)
			for m in msgs:
				_say(m)
			msgs.append_array(_finish_time("rest", []))
		"defeat":
			heir.clean_streak = 0
			killer_id = ""
			for e in b.enemies:
				if e["hp"] > 0:
					killer_id = e["id"]
					break
			if heir.trait_total("extra_life") > 0.0 and not heir.extra_life_used:
				heir.extra_life_used = true
				heir.hp = heir.max_hp()
				msgs.append(GameMessages.text("life", "death_refuses", {"name": heir.name}))
				msgs.append_array(party_msgs)
				for m in msgs:
					_say(m)
				msgs.append_array(_finish_time(battle_kind, []))
			elif rng.randf() < float(GameData.bal("death_chance_on_defeat")):
				msgs.append(GameMessages.text("life", "slain_in_battle", {"name": heir.name}))
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
				msgs.append(GameMessages.text("life", "dragged", {"name": heir.name, "loss": GameText.num(loss)}))
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


## The one way time passes: `years` go by for the heir, the party and the world. Actions reach it through
## _finish_time with whole years; the world clock (GameClock) reaches it with the spans real time adds up to.
func pass_time(years: float, msgs: Array = []) -> Array:
	return _pass_years(years, msgs)


## Time passes for the heir and the world: ageing, milestones, weather, death of old age.
func _pass_years(years: float, msgs: Array) -> Array:
	loot = {}   # moving on leaves the dead unsearched
	for m in msgs:
		_say(m)
	if state != "life":
		return msgs
	if not heir.spell_news.is_empty():
		var learned := GameMessages.text("life", "learns_spell", {"name": heir.name, "spells": GameMessages.text("life", "list_and").join(heir.spell_news.map(func(id): return GameCombat.spell(id).get("name", id)))})
		heir.spell_news = []
		msgs.append(learned)
		_say(learned)
	GameSkills.on_years(self, msgs)
	GameFeats.on_years(self, msgs)
	GameSkillTree.on_years(self, msgs)
	heir.age += years
	world.advance(years, rng)
	GameWorldEvents.on_years(self, years, msgs)   # a war, a famine or a golden age may begin or end
	party.on_years(self, years, msgs)
	GameRanch.on_years(self, years, msgs)
	GameRaids.on_years(self, years, msgs)   # a house with animals or a built house may be raided
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
		return [GameMessages.text("life", "too_soon_retire")]
	_say(GameMessages.text("life", "retires", {"name": heir.name}))
	return _die("old age")


# ---------------------------------------------------------------- death & succession

func _die(cause: String) -> Array:
	var msgs: Array = []
	loot = {}   # the dead of the last fight are the fallen heir's, not the next one's
	var rec := {
		"gen": gen, "name": heir.full_name(), "class_id": heir.class_id, "race_id": heir.race_id,
		"traits": heir.traits.map(func(t): return GameData.trait_name(t)),
		"level": heir.level, "age": int(heir.age), "cause": cause, "gold": heir.gold,
		"battles_won": heir.battles_won, "kills": heir.kills.duplicate(),
		"parents": heir.parent_names.duplicate(), "archetype": heir.archetype,
		"children": heir.children.map(func(c): return c.name),
		"spouse": heir.spouse.name if heir.spouse != null else "",
	}
	if not heir.titles.is_empty():   # the heir's titles go into their record; a personal title ends with them
		rec["titles"] = heir.titles.duplicate()
	history.append(rec)
	ages.on_death(self, rec)
	msgs.append(GameMessages.text("life", "dies_old_age", {"name": heir.name, "age": int(heir.age)}) if cause == "old age" else GameMessages.text("life", "dies_cause", {"name": heir.name, "cause": _cause_text(cause), "age": int(heir.age)}))
	if cause == "slain in battle":
		if killer_id != "":
			_add_echo("slayer", killer_id, GameMessages.text("life", "echo_fell", {"name": heir.name, "foe": _creature_name(killer_id)}), 0.15)
	elif heir.level >= glory_level(heir):
		var strength := 0.1 * float(heir.level) / glory_level(heir)
		_add_echo("glory", "life", GameMessages.text("life", "echo_celebrated", {"name": heir.name}), clampf(strength, 0.0, 0.2))
	var line_ends := GameHardMode.line_ends(self, cause)
	if gen >= GameHardMode.last_gen(self) or line_ends:
		last_death = rec
		GameAges.end_saga(self, msgs)
		if line_ends:
			msgs.append(GameHardMode.line_ends_text(self))
		for m in msgs:
			_say(m)
		return msgs
	var kids: Array = heir.children
	if kids.is_empty():
		var adoptees := _adoptees()
		if adoptees.is_empty():
			msgs.append(GameMessages.text("life", "no_children_cousins", {"name": heir.name}))
			kids = _cousins()
		else:
			msgs.append(GameMessages.text("life", "no_children_adopted", {"name": heir.name}))
			kids = adoptees
			if kids.size() < 2:
				kids.append_array(_cousins(2 - kids.size()))
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


## Companions of the house who can be adopted as heirs when there are no children: in party order, up to
## adoption_max. Each keeps their own race and class and takes the dynasty name; traits pass with the same
## penalty as a cousin's. Nothing leaves the party until one of them is chosen (see choose_heir).
func _adoptees() -> Array:
	var out: Array = []
	for m in party.members:
		if out.size() >= int(GameData.bal("adoption_max")):
			break
		var def_c := GameParty.def(str(m["id"]))
		var res := GameInheritance.inherit([heir], rng, float(GameData.bal("adopted_inherit_penalty")))
		var c := GameHeir.new()
		c.id = _take_id()
		c.sex = GameSex.roll(seed_value, c.id)
		c.name = str(m["name"]).split(" ")[0]
		c.surname = dynasty_name
		c.race_id = str(def_c.get("race", heir.race_id))
		c.class_id = str(def_c.get("class", heir.class_id))
		c.traits = res["traits"]
		c.dormant = res["dormant"]
		c.companion_id = str(m["id"])
		c.parent_names = ["(companion %s)" % heir.name]
		c.fate_value = GameFate.roll_fate_value(rng, c.fate_modifier_total())
		c.lifespan = c.compute_lifespan()
		out.append(c)
	return out


func _cousins(count: int = 2) -> Array:
	var out: Array = []
	for i in count:
		var res := GameInheritance.inherit([heir], rng, float(GameData.bal("adopted_inherit_penalty")))
		var c := GameHeir.new()
		c.id = _take_id()
		c.sex = GameSex.roll(seed_value, c.id)
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
		msgs.append(GameMessages.text("life", "archetype_is", {"name": c.name, "archetype": GameFate.archetype_name(pending_archetype), "desc": GameFate.archetype_desc(pending_archetype)}))
		if pending_archetype == "rebel":
			var ids := GameData.starting_ids(GameData.classes).filter(func(x): return x != parent.class_id)
			c.class_id = ids[rng.randi() % ids.size()]
			msgs.append(GameMessages.text("life", "rejects_trade", {"name": c.name, "cls": c.cls()["name"]}))
		if pending_archetype == "redeemer":
			for t in c.traits:
				if GameData.trait_def(t).get("category", "") == "curse":
					c.traits.erase(t)
					c.dormant.append(t)
					msgs.append(GameMessages.text("life", "shed_burden", {"name": c.name, "trait": GameData.trait_name(t)}))
					break
	pending_archetype = ""
	world.visit(GameData.world["start"])
	if c.companion_id != "":
		var m := party.member(c.companion_id)
		if not m.is_empty():
			party._part(self, m, "adopted")
			msgs.append(GameMessages.text("life", "leaves_company", {"name": c.name}))
		c.companion_id = ""
	_setup_new_heir(c)
	var born_to := GameSubclass.on_succession(self, parent, c)   # a child may be born to the parent's calling (own dice)
	if born_to != "":
		msgs.append(born_to)
	GameSkillTree.inherit(self, parent, c, msgs)
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
	_say(GameMessages.text("life", "generation_takes_name", {"gen": GameText.num(gen), "name": c.full_name()}))
	if gen == GameHardMode.last_gen(self):
		msgs.append(GameAges.text("last_heir", {"heir": c.name, "house": dynasty_name}))
	for m in msgs:
		_say(m)
	# Re-roll nothing: fate value was rolled at birth. Run the first milestone.
	_check_milestone("coming_of_age")
	_say(GameMessages.text("life", "inherited_gold", {"gold": GameText.num(c.gold)}))
	return msgs


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var out := {
		"version": 1, "seed": seed_value, "rng_state": str(rng.state), "dynasty_name": dynasty_name,
		"gen": gen, "heir": heir.to_dict(), "state": state, "history": history, "echoes": echoes,
		"heirlooms": heirlooms, "slain_bosses": slain_bosses, "pending_archetype": pending_archetype,
		"candidates": candidates.map(func(c): return c.to_dict()), "last_death": last_death,
		"journal": journal.slice(maxi(0, journal.size() - JOURNAL_SAVED)), "next_id": next_id, "total_hunts": total_hunts,
		"killer_id": killer_id, "world": world.to_dict(), "flags": flags,
		"quests": quests.to_dict(), "party": party.to_dict(), "pending_event": pending_event,
		"shop_state": shop_state, "ages": ages.to_dict(), "auto_battle": auto_battle, "loot": loot,
	}
	if not roster.is_empty():   # only once something is found: older saves and fresh ones stay alike
		out["roster"] = roster
	if not stores.is_empty():   # likewise: only once something is gathered
		out["stores"] = stores
	if not mine.is_empty():   # and only once something is dug
		out["mine"] = mine
	if not built.is_empty():   # and only once something is built
		out["built"] = built
	if not gathered.is_empty():   # and only once a companion has gathered
		out["gathered"] = gathered
	if not house.is_empty():   # only once something is bought: older saves and fresh ones stay alike
		out["house"] = house
	if world_seconds > 0.0:   # likewise: only once the clock has run
		out["world_seconds"] = world_seconds
	if clock_carry > 0.0:   # only once the clock holds time: older saves and fresh ones stay alike
		out["clock_carry"] = clock_carry
	if not house_titles.is_empty():   # only once earned
		out["house_titles"] = house_titles
	if not achievements.is_empty():   # only once reached
		out["achievements"] = achievements
	if not world_event.is_empty():   # only while one runs or the world rests after one
		out["world_event"] = world_event
	if not auto_party.is_empty():   # only once the player has set a switch: older saves and fresh ones stay alike
		out["auto_party"] = auto_party
	if not hard.is_empty():   # only for a house founded with a hard-mode option
		out["hard"] = hard
	return out


static func from_dict(d: Dictionary) -> GameDynasty:
	GameData.load_all()
	var g := GameDynasty.new()
	g.seed_value = int(d["seed"])
	g.rng.seed = g.seed_value
	g.rng.state = int(d["rng_state"])
	g.dynasty_name = d["dynasty_name"]
	g.gen = int(d["gen"])
	g.heir = GameHeir.from_dict(d["heir"])
	g.heir.spell_news.append_array(g.heir.learn_spells())   # a spell list grown since the save
	g.state = d["state"]
	g.history = _ints(Array(d["history"]))
	g.ages = GameAges.from_dict(d.get("ages"), g)
	g.echoes = Array(d["echoes"])
	for e in g.echoes:
		e["gen"] = int(e["gen"])
		e["strength"] = snappedf(float(e["strength"]), GameFate.STEP)
	g.heirlooms = GameHeirlooms.load_list(_ints(Array(d["heirlooms"])))
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
	g.house = GameHouse.from_dict(d.get("house", {}))
	g.roster = GameRoster.load_list(d.get("roster", []))
	g.stores = GameCraft.load_stores(d.get("stores", {}))
	g.mine = GameMine.load_state(d.get("mine", {}))
	g.built = GameBuild.load_state(d.get("built", {}))
	g.gathered = GameCompanions.load_gathered(d.get("gathered", {}))
	g.house_titles = GameTitles.clean_ids(d.get("house_titles", []))
	g.achievements = GameAchievements.load_state(d.get("achievements", {}))
	g.world_event = GameWorldEvents.load_state(d.get("world_event", {}))
	g.world_seconds = GameDay.load_seconds(d.get("world_seconds", 0.0))
	var carry = d.get("clock_carry", 0.0)
	g.clock_carry = maxf(0.0, float(carry)) if (typeof(carry) == TYPE_FLOAT or typeof(carry) == TYPE_INT) and is_finite(float(carry)) else 0.0
	g.pending_event = _ints(d.get("pending_event", {}))
	g.shop_state = _ints(d.get("shop_state", {}))
	g.auto_battle = bool(d.get("auto_battle", false))
	var ap = d.get("auto_party", {})
	if typeof(ap) == TYPE_DICTIONARY:
		for k in ["heir", "companion_default"]:
			if typeof(ap.get(k)) == TYPE_BOOL:
				g.auto_party[k] = ap[k]
	g.loot = GamePlague.load_loot(d.get("loot", {})) if g.state == "life" else {}
	g.hard = GameHardMode.load_state(d.get("hard"))
	var cause: Variant = g.last_death.get("cause", "")
	# no heir is chosen past the last generation, or after a death that ends the line
	if g.state == "succession" and (g.gen >= GameHardMode.last_gen(g) or GameHardMode.line_ends(g, cause if typeof(cause) == TYPE_STRING else "")):
		GameAges.end_saga(g, [])
	_fill_sexes(g)
	if typeof(d.get("battle")) == TYPE_STRING and g.state == "life":
		g._restore_battle(str(d["battle"]))
	return g


## The dynasty as its save file holds it: to_dict() at this game's save version (GameSaveVersion), with the
## fight in progress when there is one. The fight is kept exactly, ints and floats as they were (Godot's own
## encoding in base64, values only), so after a load it plays on as if the game had never closed. to_dict()
## keeps the shape the golden digests were taken from and never holds the fight.
func to_save() -> Dictionary:
	var out := to_dict()
	out["version"] = GameSaveVersion.CURRENT
	if battle != null:
		var fight := {"kind": battle_kind, "battle": battle.to_dict()}
		if command_round != null and command_round.b == battle:
			fight["round"] = command_round.to_dict()
		out["battle"] = Marshalls.variant_to_base64(fight)
	return out


## Brings back a fight saved by to_save(): its companions rebuilt from the party, its round, its kind. A save
## that does not hold a whole fight (damaged, or its companions gone) loads without it, as before the fight.
func _restore_battle(text: String) -> void:
	var shape := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")   # checked first so the engine never logs a decode error
	if text.length() % 4 != 0 or shape.search(text) == null:
		return
	var v = Marshalls.base64_to_variant(text, false)   # values only: a save can never carry an object in
	if typeof(v) != TYPE_DICTIONARY or typeof(v.get("battle")) != TYPE_DICTIONARY:
		return
	var saved: Dictionary = v["battle"]
	var allies: Array = []
	for a in saved.get("allies", []):
		var m := party.member(str(a.get("id", ""))) if typeof(a) == TYPE_DICTIONARY else {}
		if m.is_empty():
			return
		allies.append(party.unit(self, m))
	var b := GameBattle.restore(saved, heir, rng, allies)
	if b == null:
		return
	battle = b
	battle_kind = str(v.get("kind", "hunt"))
	command_round = null
	if typeof(v.get("round")) == TYPE_DICTIONARY:
		command_round = GameRound.restore(v["round"], b, auto_party, party)


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


## Saves the dynasty, a fight in progress included: closing the game mid-fight neither loses the fight nor
## undoes it.
func save_to_disk() -> bool:
	if not GameSaves.write_atomic(save_path, JSON.stringify(to_save())):
		return false
	GameHardMode.after_save(self, save_path)
	return true


## True when the save file, or the ".bak" kept beside it, exists.
static func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")


## The saved dynasty, or null. A missing or damaged file falls back to the ".bak" the last save kept.
static func load_from_disk() -> GameDynasty:
	var d := GameSaves.load_file(save_path)
	if d == null:
		d = GameSaves.load_file(save_path + ".bak")
	return d


## Saves from before sexes existed: each person without one is given the sex the game would have rolled, and
## a spouse without one is the opposite of the heir they married.
static func _fill_sexes(g: GameDynasty) -> void:
	_fill_sex(g.heir, g)
	for c in g.candidates:
		_fill_sex(c, g)


static func _fill_sex(h: GameHeir, g: GameDynasty) -> void:
	if h == null:
		return
	if not GameSex.valid(h.sex):
		h.sex = GameSex.roll(g.seed_value, h.id)
	if h.spouse != null and not GameSex.valid(h.spouse.sex):
		h.spouse.sex = GameSex.opposite(h.sex)
	for c in h.children:
		_fill_sex(c, g)
