## The Verdant Court and the gates between the realms (roadmap item 58, second part): the three creatures of the Court
## (their realm, spawn, sprite, size, behaviour and drops), the validators' refusal of broken data, the gates
## (`gate_open`, and `open_gate` told once and only once), a creature taken to a realm only through the open gates it
## leaves and enters, young of two worlds only when both gates are open, the Standing Stones event that opens the
## Verdant gate, saving (the gate flags are the only thing that changes), and a house with no gate open living its
## years exactly as one whose worlds are not linked.
## Run: godot --headless --path . -s res://tests/test_game_realm_gates.gd
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const VERDANT_LINE := "The way to the Verdant Court is open: creatures and heirs can cross to it now."
const SHUT_LINE := "The way to the Verdant Court is shut. Nothing crosses it yet."

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_creatures()
	test_validators()
	test_gates()
	test_move_gated()
	test_open_once()
	test_young_of_two_worlds()
	test_event()
	test_saving()
	test_house_without_gates()
	print("realm gates tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	d.house[GameHouse.RANCH] = 3
	return d


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameRealms.data().duplicate(true)
	edit.call(GameRealms.data())
	body.call()
	GameRealms._cache = saved


func _adult(d: GameDynasty, species: String, sex: String, name: String = "") -> Dictionary:
	var e := GameRoster.add(d, species, name if name != "" else species + "_" + sex)
	e["sex"] = sex
	e["stage"] = "adult"
	e["age"] = (GameRanch.egg_years(e) + float(GameRanch.size_of(species)["young"]) + GameRanch.adult_at(e)) * 0.5
	return e


func _broken_realms(edit: Callable) -> bool:
	var bad := [false]
	_with(edit, func(): bad[0] = not GameRealms.validate().is_empty())
	return bad[0]


# ---------------------------------------------------------------- the three creatures

func test_creatures() -> void:
	var born := {"thornhound": "live", "moss_stag": "live", "glimmer_moth": "egg"}
	for id in born:
		ok(GameRealms.of(id) == "verdant", "%s is of the Verdant Court" % id)
		ok(GameBirth.born(id) == born[id], "%s is %s-born" % [id, born[id]])
		ok(not GameCombat.creature_def(id).is_empty() and GameCombat.creature_def(id).get("biomes", []).has("fae"), "%s lives in the fae" % id)
		ok(GameSpawn.data()["creatures"].has(id), "%s has a spawn entry" % id)
		ok(GameSpawn.data()["creatures"][id]["surface"] == ["forest"], "%s roams the forest surface, which the fae biome is" % id)
		ok(GameRanch.data()["size_of"].has(id) and not GameRanch.size_of(id).is_empty(), "%s has a size" % id)
		ok(GameCraft.data()["drops"].has(id), "%s leaves something when hunted" % id)
		ok(SpriteArt.has_creature(id), "%s has a sprite" % id)
		ok(GameBreeding.family_of(id) != "", "%s is in a breeding family" % id)
		ok(not GameBehaviour.data()["creatures"].get(id, []).is_empty(), "%s has behaviour tags" % id)
		ok(GameBehaviour.params(id)["hostile"] == true, "%s is hostile in the data, as every wild creature must be" % id)
	ok(GameBehaviour.params("thornhound")["hostile"] and GameBehaviour.params("thornhound")["sight"] > 7.0, "the thornhound hunts by sight")
	ok(GameBehaviour.params("moss_stag")["skittish"] == true and GameBehaviour.params("moss_stag")["herd_radius"] > 0.0, "the moss stag keeps to its herd and runs")
	ok(GameBehaviour.params("glimmer_moth")["flier"] == true, "the glimmer moth flies")
	ok(GameCraft.data()["drops"]["glimmer_moth"]["materials"][0]["material"] == "silk", "a glimmer moth leaves silk")
	ok(GameRanch.data()["work_of"].get("thornhound", {}).get("kind") == "guard", "a thornhound works as a guard")
	ok(GameSpawn.table(GameSpawn.context("forest", -1, 20, "summer", "clear", false, "")).any(func(x): return x["id"] == "thornhound"), "a thornhound is found in the forest, once it is old enough to be there")
	ok(SpriteArt.style_problems().is_empty(), "every sprite, the three included, keeps to the art style: %s" % str(SpriteArt.style_problems().slice(0, 3)))


# ---------------------------------------------------------------- the validators refuse broken data

func test_validators() -> void:
	ok(GameRealms.validate().is_empty(), "the realm data is sound")
	ok(GameEvents.validate().is_empty(), "the event data is sound: %s" % str(GameEvents.validate().slice(0, 3)))
	ok(_broken_realms(func(x): x["of"]["thornhound"] = "moon"), "a creature of a realm that does not exist is refused")
	ok(_broken_realms(func(x): x["of"]["glimmer_moth"] = "material"), "a moth listed as of home is refused")
	ok(_broken_realms(func(x): x["settings"]["gate_prefix"] = ""), "a gate with no flag name is refused")
	ok(_broken_realms(func(x): x["text"].erase("gate_shut")), "a gate with no line for a shut gate is refused")
	ok(_broken_realms(func(x): x["text"].erase("gate_open")), "a gate with no line for an open gate is refused")
	var saved: Array = GameData.events.duplicate(true)
	var ev := {}
	for e in GameData.events:
		if e["id"] == "verdant_stones":
			ev = e
	var gate_outcome: Dictionary = ev["choices"][0]["outcomes"]["always"]
	gate_outcome["gate"] = "material"
	ok(GameEvents.validate().any(func(p): return "gate names 'material'" in str(p)), "an event that opens home's gate is refused")
	gate_outcome["gate"] = "moon"
	ok(GameEvents.validate().any(func(p): return "gate names 'moon'" in str(p)), "an event that opens a realm that does not exist is refused")
	gate_outcome["gate"] = "verdant"
	ok(GameEvents.validate().is_empty(), "and the gate of the Court is accepted")
	GameData.events = saved


# ---------------------------------------------------------------- gates

func test_gates() -> void:
	var d := dyn()
	ok(GameRealms.gate_flag("verdant") == "gate_verdant", "a gate's flag is its realm's name after the prefix")
	ok(GameRealms.gate_open(d, "material"), "home's gate is always open")
	ok(not GameRealms.gate_open(d, "verdant"), "the Verdant gate starts shut")
	ok(GameRealms.gateable("verdant") and not GameRealms.gateable("material") and not GameRealms.gateable("moon"), "only the other realms have gates")
	d.flags["gate_verdant"] = 3
	ok(GameRealms.gate_open(d, "verdant"), "a gate whose flag is set is open")
	ok(not GameRealms.gate_open(d, "hollow"), "one gate open does not open another")


# ---------------------------------------------------------------- moving only through open gates

func test_move_gated() -> void:
	var d := dyn()
	var th := _adult(d, "thornhound", "male", "Thorn")
	var id := int(th["id"])
	ok(GameRealms.why_not(d, id, "verdant") == GameRealms.text("gate_shut", {"realm": "the Verdant Court"}), "a thornhound is not taken through a shut gate: %s" % GameRealms.why_not(d, id, "verdant"))
	ok(GameRealms.why_not(d, id, "verdant") == SHUT_LINE, "and it is told so in words the player can read")
	ok(not GameRealms.move(d, id, "verdant")["ok"] and not th.has("in_realm"), "the move is refused, and the creature stays where it is")
	ok(GameRealms.open_gate(d, "verdant") == VERDANT_LINE, "the gate opens and says so")
	var got := GameRealms.move(d, id, "verdant")
	ok(got["ok"] and th["in_realm"] == "verdant" and GameRealms.settled(th), "once the gate is open the thornhound crosses, and it is at ease in its own realm")
	d.flags.erase("gate_verdant")
	ok(GameRealms.why_not(d, id, "material") == SHUT_LINE, "leaving a realm needs its gate too")
	d.flags["gate_verdant"] = d.gen
	ok(GameRealms.move(d, id, "material")["ok"] and not th.has("in_realm"), "and through the open gate it comes home")
	var moth := _adult(d, "glimmer_moth", "female", "Wisp")
	d.flags.erase("gate_verdant")
	ok(not GameRealms.move(d, int(moth["id"]), "verdant")["ok"], "a moth is held by the same gate")
	d.flags["gate_verdant"] = d.gen
	ok(GameRealms.move(d, int(moth["id"]), "verdant")["ok"], "and crosses through the same open gate")


# ---------------------------------------------------------------- opened once, told once

func test_open_once() -> void:
	var d := dyn()
	ok(GameRealms.open_gate(d, "verdant") == VERDANT_LINE, "the first opening is told")
	ok(GameRealms.open_gate(d, "verdant") == "", "the second opening is not told again")
	ok(d.flags["gate_verdant"] == d.gen, "the flag says the generation it opened in")
	ok(GameRealms.open_gate(d, "material") == "" and GameRealms.open_gate(d, "moon") == "", "home has no gate to open, and nor does a realm that is not one")
	ok(not GameRealms.open_gate(d, "moon").length() > 0, "an unknown realm opens nothing")


# ---------------------------------------------------------------- young of two worlds

func test_young_of_two_worlds() -> void:
	var d := dyn()
	var mother := _adult(d, "thornhound", "female", "Thistle")
	var father := _adult(d, "wolf", "male", "Grey")
	var e1 := GameRoster.add(d, "thornhound", "Bramble")
	ok(GameRealms.on_birth(d, e1, mother, father).is_empty() and not e1.has("realms") and not e1.has("marks"), "with the Verdant gate shut, young of the Court and home carry neither world nor mark")
	GameRealms.open_gate(d, "verdant")
	var e2 := GameRoster.add(d, "thornhound", "Briar")
	var lines := GameRealms.on_birth(d, e2, mother, father)
	ok(e2.get("realms") == ["verdant", "material"] and e2.get("marks") == ["glamoured"], "with the gate open they carry both worlds and the Court's mark: %s %s" % [str(e2.get("realms")), str(e2.get("marks"))])
	ok(lines.size() == 1 and "carries two worlds" in str(lines[0]), "and it is told")
	# two worlds need both gates: a drake of the Dragon Isles with a thornhound
	var drake := _adult(d, "drake", "male", "Ember")
	var hound := _adult(d, "thornhound", "female", "Fen")
	var e3 := GameRoster.add(d, "thornhound", "Ash")
	ok(GameRealms.on_birth(d, e3, drake, hound).is_empty() and not e3.has("realms"), "the Verdant gate open is not enough: the Dragon Isles' gate must open too")
	GameRealms.open_gate(d, "dragon_isles")
	var e4 := GameRoster.add(d, "thornhound", "Cinder")
	GameRealms.on_birth(d, e4, drake, hound)
	ok(e4.get("realms") == ["dragon_isles", "verdant"] and e4.get("marks") == ["sky_born", "glamoured"], "with both open, the young carry both: %s %s" % [str(e4.get("realms")), str(e4.get("marks"))])
	var plain := GameRoster.add(d, "wolf", "Pup")
	ok(GameRealms.on_birth(d, plain, father, father).is_empty() and not plain.has("realms"), "a pair of home has no gates to pass")
	var off := [false]
	_with(func(x): x["settings"]["linked"] = false, func():
		var e5 := GameRoster.add(d, "thornhound", "Moss")
		GameRealms.on_birth(d, e5, mother, father)
		off[0] = not e5.has("realms") and not e5.has("marks"))
	ok(off[0], "with the worlds unlinked, nothing is written even through open gates")


# ---------------------------------------------------------------- the Standing Stones

func test_event() -> void:
	var ev := GameEvents.event_def("verdant_stones")
	ok(not ev.is_empty() and ev.get("once", false) and ev["where"]["places"] == ["elderglade"], "the Standing Stones are at Elderglade, once")
	ok(ev["requires"]["flags"] == ["fae_danced"], "and need a dance with the fair folk first")
	var dance := GameEvents.event_def("fae_ring")
	var flagged := false
	for c in dance["choices"]:
		if c["text"] == "Join the dance":
			flagged = c["outcomes"]["success"].get("flag", "") == "fae_danced" and c["outcomes"]["crit_success"].get("flag", "") == "fae_danced"
	ok(flagged, "dancing in the fae ring sets the flag the stones need")
	var d := dyn()
	d.world.location = "elderglade"
	ok(not GameEvents.is_eligible(d, ev), "not open to an heir who has not danced")
	d.flags["fae_danced"] = d.gen
	ok(GameEvents.is_eligible(d, ev), "open to one who has, at Elderglade")
	ok(GameEvents.begin(d, "verdant_stones"), "the event begins")
	ok(not GameRealms.gate_open(d, "verdant"), "the gate is shut until the heir chooses")
	GameEvents.resolve(d, 1)
	ok(not GameRealms.gate_open(d, "verdant"), "keeping to the path opens nothing")
	ok(not GameEvents.is_eligible(d, ev), "and the stones are seen once")
	var e := dyn()
	e.world.location = "elderglade"
	e.flags["fae_danced"] = e.gen
	GameEvents.begin(e, "verdant_stones")
	GameEvents.resolve(e, 0)
	ok(GameRealms.gate_open(e, "verdant"), "walking through the gap opens the Verdant gate")
	ok(str(e.journal).contains(VERDANT_LINE), "and the line is told in the journal")
	var kept := _adult(e, "thornhound", "male", "Thorn")
	ok(GameRealms.move(e, int(kept["id"]), "verdant")["ok"], "a creature can now cross")


# ---------------------------------------------------------------- saving

func test_saving() -> void:
	var d := dyn()
	_adult(d, "thornhound", "male", "Thorn")
	var before: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	GameRealms.open_gate(d, "verdant")
	var after: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var expect_flags: Dictionary = before["flags"].duplicate()
	expect_flags["gate_verdant"] = float(d.gen)
	ok(after["flags"] == expect_flags, "the gate is saved as a story flag, and nothing else in the flags moves")
	var changed: Array = []
	for k in before:
		if k != "flags" and before[k] != after.get(k):
			changed.append(k)
	ok(changed.is_empty(), "opening a gate changes nothing else in the save: %s" % str(changed))
	var back := GameDynasty.from_dict(after)
	ok(GameRealms.gate_open(back, "verdant") and not GameRealms.gate_open(back, "hollow"), "the open gate comes back after a save and load")
	ok(back.roster == d.roster, "and the roster is as it was")


# ---------------------------------------------------------------- a house with no gate open

func test_house_without_gates() -> void:
	# the same ranch and the same years, with the worlds linked (gates shut) and with them not linked at all
	var saved_breeding: Dictionary = GameBreeding.data().duplicate(true)
	GameBreeding.data()["settings"]["fertility"] = {"pure": 1.0, "hybrid": 1.0, "cross": 1.0}
	var results: Array = []
	for linked in [true, false]:
		_with(func(x): x["settings"]["linked"] = linked, func():
			var d := dyn(9)
			var mother := _adult(d, "thornhound", "female", "Mother")
			var father := _adult(d, "wolf", "male", "Father")
			mother["breeding"] = true
			father["breeding"] = true
			_adult(d, "glimmer_moth", "female", "Wisp")
			var msgs: Array = []
			GameBreeding.on_years(d, 1.0, msgs, 1.0)
			var first := d.roster.filter(func(e): return e.get("bred", false))
			ok(first.size() == 1 and not first[0].has("realms") and not first[0].has("marks"), "a hound and a wolf have young with no worlds in them, linked or not")
			for i in 5:
				d.pass_time(1.0)
			var young := d.roster.filter(func(e): return e.get("bred", false))
			ok(young.size() >= 1 and young.all(func(e): return not e.has("realms") and not e.has("marks")), "and their young over five more years carry no worlds either")
			results.append([d.to_dict(), d.rng.state]))
	GameBreeding._cache = saved_breeding
	ok(results.size() == 2 and results[0][0] == results[1][0] and results[0][1] == results[1][1], "with no gate open, a house lives its years exactly as one not linked")
