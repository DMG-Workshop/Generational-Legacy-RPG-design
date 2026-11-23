## Spellcasting as a shop service (core/game/game_casting.gd, data/shops/casting.json, ui/play/shop_panel.gd): healing and cleansing at once, a blessing
## laid on the party for the next fight and applied when it begins, one at a time, lapsing after its fight, its year or its heir; a cooldown of a day;
## every refusal; no dice; the dynasty's marks survive a save and load clean; the panel draws; and every check has a break.
## Run: godot --headless --path . -s res://tests/test_game_casting.gd
extends SceneTree

const ShopPanel := preload("res://ui/play/shop_panel.gd")

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
	test_heal_and_cleanse()
	test_blessing()
	test_refusals()
	test_save()
	await test_panel()
	test_breaks()
	print("casting tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _hour(d: GameDynasty, hour: float, day: int = 0) -> void:
	var span := float(GameDay.setting("day_seconds"))
	d.world_seconds = fposmod(hour / 24.0 - float(GameDay.setting("start_phase")), 1.0) * span + span * float(day)


func _dyn(place: String = "kingshold") -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	d.world.location = place
	_hour(d, 12.0)
	return d


func test_data() -> void:
	ok(GameCasting.validate().is_empty(), "the data is sound: %s" % str(GameCasting.validate()))
	ok(GameCasting.rows("spell_shop").size() == 5 and GameCasting.rows("bakery").is_empty(), "the spell shop casts five and the baker none")
	ok(GameCasting.kind_of("ward") == "blessing" and GameCasting.kind_of("fireball") == "", "only the party spells are for sale")
	var d := _dyn()
	var sv := GameCasting.row("spell_shop", "cast_ward")
	var mp := int(GameCombat.spell("ward")["mp"])
	var expected := int(round(float(mp) * 6.0 * (1.0 + 0.1 * 7.0) * GameItems.price_mult(d)))
	ok(GameCasting.price(d, sv) == maxi(1, expected), "the price is mp x mp_gold x (1 + price_step per level) x the shop's prices: %d" % GameCasting.price(d, sv))


func test_heal_and_cleanse() -> void:
	var d := _dyn()
	var h := d.heir
	h.hp = 1
	var st := d.rng.state
	var gold := h.gold
	var price := GameCasting.price(d, GameCasting.row("spell_shop", "cast_mass_heal"))
	var line := GameCasting.cast(d, "spell_shop", "cast_mass_heal")
	ok(d.rng.state == st, "no die of the dynasty's is drawn")
	ok(h.hp > 1 and h.gold == gold - price, "the heir is mended and pays: %s" % line)
	var need := GameCasting.plan(d, "spell_shop", "cast_mass_heal")
	ok(not need["ok"] and str(need["why"]).contains("cast"), "a second cast the same day is refused: %s" % need["why"])
	_hour(d, 12.0, 1)
	ok(h.hp < h.max_hp() and GameCasting.plan(d, "spell_shop", "cast_mass_heal")["ok"], "the next day it may be cast again")
	# a sick heir
	var s := _dyn("hearthmere")
	var did := str(GameDisease.all()[0]["id"])
	GameDisease.infect(s.heir, did, "test")
	ok(s.heir.diseases.size() == 1, "a sick heir")
	var before := s.heir.gold
	GameCasting.cast(s, "apothecary", "cast_cleanse")
	ok(s.heir.diseases.is_empty() and s.heir.gold < before, "the sickness is washed away for a price")
	ok(not GameCasting.plan(s, "apothecary", "cast_cleanse")["ok"], "and there is nothing more to cleanse")


func test_blessing() -> void:
	var d := _dyn()
	var line := GameCasting.cast(d, "spell_shop", "cast_ward")
	ok(not d.blessing.is_empty() and str(d.blessing["spell"]) == "ward" and line.contains("next fight"), "a ward is laid for the next fight: %s" % line)
	ok(not GameCasting.blessing(d).is_empty(), "and it holds")
	ok(not GameCasting.plan(d, "spell_shop", "cast_ward")["ok"], "the same blessing is not bought twice in a day")
	var wsv := GameCasting.row("spell_shop", "cast_ward")
	wsv["daily"] = false
	ok(not GameCasting.plan(d, "spell_shop", "cast_ward")["ok"] and str(GameCasting.plan(d, "spell_shop", "cast_ward")["why"]).contains("already"), "nor while it is still laid, with no daily limit")
	wsv["daily"] = true
	# a second one replaces it
	var line2 := GameCasting.cast(d, "spell_shop", "cast_haste")
	ok(str(d.blessing["spell"]) == "haste" and line2.contains("replaces"), "a second replaces the first: %s" % line2)
	# a fight applies it, once
	var f := d.start_hunt("hunt")
	ok(f != null, "a hunt begins")
	var shielded := f.status_of("heir", "haste")
	ok(not shielded.is_empty(), "the blessing is on the heir when the fight begins")
	ok(d.blessing.is_empty(), "and it lapses after its fight")
	d.battle = null
	var d2 := _dyn()
	GameCasting.cast(d2, "spell_shop", "cast_ward")
	d2.world.year += 2.0
	ok(GameCasting.blessing(d2).is_empty(), "a blessing lapses with its year")
	var d3 := _dyn()
	GameCasting.cast(d3, "spell_shop", "cast_ward")
	d3.gen += 1
	ok(GameCasting.blessing(d3).is_empty(), "and with its heir")
	# a fight with no blessing is exactly as before
	var a := _dyn()
	var b := _dyn()
	var fa := a.start_hunt("hunt")
	var fb := b.start_hunt("hunt")
	ok(fa.statuses == fb.statuses and a.rng.state == b.rng.state, "with none laid, a fight begins exactly as before")


func test_refusals() -> void:
	var d := _dyn()
	ok(GameCasting.cast(d, "bakery", "cast_ward").contains("does not cast"), "not at a baker's")
	ok(GameCasting.cast(d, "spell_shop", "nope").contains("does not cast"), "an unknown service")
	var far := _dyn("hearthmere")
	ok(GameCasting.cast(far, "spell_shop", "cast_ward").contains("There is no"), "not in a town without the shop")
	_hour(d, 5.0)
	ok(GameCasting.cast(d, "spell_shop", "cast_ward").contains("shut"), "not while the shop is shut")
	_hour(d, 12.0)
	d.heir.gold = 1
	ok(GameCasting.plan(d, "spell_shop", "cast_ward")["why"].contains("cannot afford"), "not without the gold")
	d.heir.gold = 100000
	var f := d.start_hunt("hunt")
	ok(GameCasting.plan(d, "spell_shop", "cast_ward")["why"].contains("Not in a fight"), "not in a fight")
	d.battle = null
	ok(f != null, "(the fight was a real one)")


func test_save() -> void:
	var d := _dyn()
	d.heir.hp = 1
	GameCasting.cast(d, "spell_shop", "cast_ward")
	GameCasting.cast(d, "spell_shop", "cast_mass_heal")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(str(back.blessing.get("spell", "")) == "ward" and int(back.blessing["fights"]) == 1, "the blessing survives a save and load")
	ok(GameCasting.on_cooldown(back, "spell_shop", GameCasting.row("spell_shop", "cast_mass_heal")), "and so does the day's cooldown")
	ok(not _dyn().to_dict().has("blessing") and not _dyn().to_dict().has("casts_used"), "nothing is written until a spell is cast")
	ok(GameCasting.load_blessing("junk").is_empty() and GameCasting.load_blessing({"spell": "fireball", "fights": 1, "gen": 1, "level": 1, "years": 1.0, "year": 0.0}).is_empty() and GameCasting.load_blessing({"spell": "ward", "fights": "x", "gen": 1, "level": 1, "years": 1.0, "year": 0.0}).is_empty(), "damaged blessings load as none")
	ok(GameCasting.load_used({"a|b|c": "1|2", "bad": "x", "d|e|f": 3}) == {"a|b|c": "1|2"}, "damaged day marks are dropped")


func test_panel() -> void:
	var d := _dyn()
	d.heir.hp = 1
	var panel: Control = ShopPanel.new()
	panel.dynasty = d
	root.add_child(panel)
	await process_frame
	panel._show("spell_shop")
	await process_frame
	ok(panel.rows.get_child_count() >= 6, "the spell shop's tab has its spells")
	panel._act(GameCasting.cast(d, "spell_shop", "cast_ward"))
	await process_frame
	ok(not d.blessing.is_empty(), "the panel's cast reaches the dynasty")
	d.world.location = "hearthmere"
	panel._rebuild()
	await process_frame
	ok(true, "and the tab draws again")
	panel.queue_free()


func test_breaks() -> void:
	var good := GameCasting._cache.duplicate(true)
	GameCasting._cache["settings"]["kinds"]["fireball"] = "blessing"
	ok(not GameCasting.validate().is_empty(), "a spell that is not a party spell is refused")
	GameCasting._cache = good.duplicate(true)
	GameCasting._cache["settings"]["level_step"] = 0.9
	ok(not GameCasting.validate().is_empty(), "a level step over 0.2 is refused")
	GameCasting._cache = good.duplicate(true)
	GameCasting._cache["text"].erase("cooldown")
	ok(not GameCasting.validate().is_empty(), "a missing line is refused")
	GameCasting._cache = good.duplicate(true)
	var sv := GameCasting.row("spell_shop", "cast_ward")
	var was := int(sv["caster_level"])
	sv["caster_level"] = 0
	ok(not GameCasting.validate().is_empty(), "a caster of level 0 is refused")
	sv["caster_level"] = was
	GameCasting._cache = good
	ok(GameCasting.validate().is_empty(), "and the data is sound again")
