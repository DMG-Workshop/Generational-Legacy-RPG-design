## Bees (roadmap follow-up to item 62): a beehive is a farm animal bought as a swarm at a town's market, kept like any creature, that
## makes honey by the season and is never slaughtered, and has no pairs: two hives of opposite sexes never breed, whatever they are set to.
## The data is checked (a hive must be a born farm animal), and the art and tags are in.
## Run: godot --headless --path . -s res://tests/test_game_hive.gd
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")

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
	test_data()
	test_market()
	test_honey()
	test_no_pairs()
	test_no_slaughter()
	print("hive tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 1000
	return d


func _grown(d: GameDynasty, species: String, sex: String = "") -> Dictionary:
	var e := GameRoster.add(d, species, "Hum")
	e["stage"] = "adult"
	e["age"] = 3.0
	e["mood"] = int(GameRanch.setting("mood_max"))
	if sex != "":
		e["sex"] = sex
	return e


func test_data() -> void:
	ok(GameBirth.is_hive("bee") and not GameBirth.is_hive("chicken") and not GameBirth.is_hive("nonesuch"), "the bee is the hive")
	ok(GameFarm.is_farm("bee") and GameBirth.born("bee") == "live" and GameBirth.young_name("bee") == "swarm", "a farm animal, born as a swarm")
	ok(not GameBirth.can_breed("bee"), "and it cannot breed")
	ok(SpriteArt.has_creature("bee") and GameBehaviour.params("bee") != null, "with art and behaviour")
	ok(GameBirth.validate().is_empty() and GameFarm.validate().is_empty(), "the data passes: %s %s" % [str(GameBirth.validate()), str(GameFarm.validate())])
	var c: Dictionary = {}
	for x in GameData.creatures:
		if x["id"] == "bee":
			c = x
	c["farm"] = false
	ok(not GameBirth.validate().is_empty(), "a hive that is not a farm animal is caught")
	c["farm"] = true
	ok(GameBirth.validate().is_empty(), "and mending it clears that")
	var ns: Array = GameFarm.data()["settings"]["no_slaughter"]
	ns.erase("bee")
	ok(not GameFarm.validate().is_empty(), "a hive with no meat and not listed as never slaughtered is caught")
	ns.append("bee")
	ok(GameFarm.validate().is_empty(), "and listing it clears that")


func test_market() -> void:
	var d := _fresh()
	ok(GameFarm.market_species().has("bee") and GameFarm.price("bee") == 28, "the market sells hives for 28")
	var gold := d.heir.gold
	var line := GameFarm.buy(d, "bee")
	ok(line.contains("swarm") and d.roster.size() == 1, "a swarm is bought: %s" % line)
	var e: Dictionary = d.roster[0]
	ok(str(e["species"]) == "bee" and str(e["stage"]) == "young" and d.heir.gold == gold - 28, "young, for its price")
	ok(not GameBreeding.can_set(e) and not GameBreeding.set_breeding(d, int(e["id"]), true), "and it cannot be set to breed")
	var back := GameRoster.load_list(JSON.parse_string(JSON.stringify(d.roster)))
	ok(back.size() == 1 and str(back[0]["species"]) == "bee", "it survives a save and load")


func test_honey() -> void:
	var d := _fresh()
	var e := _grown(d, "bee")
	var w := GameRanch.work_of("bee")
	ok(str(w["kind"]) == "honey" and int(w["gold"]) == 6, "a hive makes honey, 6 gold a year")
	var seasons := {}
	for s in ["spring", "summer", "autumn", "winter"]:
		seasons[s] = float(GameFarm.setting("season_mult")["honey"][s])
	ok(seasons["summer"] > seasons["spring"] and seasons["spring"] > seasons["autumn"] and seasons["autumn"] > seasons["winter"], "summer makes the most, winter the least")
	var earned := GameRanch.yearly_work(d)
	ok(float(earned["gold"]) > 0.0 and str(earned["kinds"].keys()[0]) == "honey", "the yearly work counts it: %s" % str(earned))
	ok(GameRanch.work_text(e).contains("honey"), "and the creature's line says so: %s" % GameRanch.work_text(e))
	e["mood"] = 0
	ok(GameRanch.work_share(e) == 0.0, "an unhappy hive makes none")


func test_no_pairs() -> void:
	var d := _fresh()
	var a := _grown(d, "bee", GameSex.FEMALE)
	var b := _grown(d, "bee", GameSex.MALE)
	a["breeding"] = true
	b["breeding"] = true
	ok(not GameBreeding.able(a) and not GameBreeding.able(b), "a hive is never able to breed, even if the flag is forced")
	ok(GameBreeding.pairs(d).is_empty(), "two hives of opposite sex make no pair")
	var n := d.roster.size()
	var lines: Array = []
	GameBreeding.on_years(d, 5.0, lines, d.world.year + 5.0)
	ok(d.roster.size() == n, "and five years bring no young")
	var cross := GameBirth.mode("bee", "chicken")
	ok(cross == "", "a hive and a hen cannot pair either")


func test_no_slaughter() -> void:
	var d := _fresh()
	var e := _grown(d, "bee")
	ok(GameFarm.slaughter_value(e) == 0, "a hive fetches nothing as meat")
	var before := d.roster.size()
	var gold := d.heir.gold
	GameFarm.slaughter(d, int(e["id"]))
	ok(d.roster.size() == before and d.heir.gold == gold, "and cannot be slaughtered")
