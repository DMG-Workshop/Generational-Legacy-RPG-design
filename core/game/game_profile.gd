## Profile bots (the balance tool's way of seeing perks the plain autopilot cannot reach; planned in docs/BALANCE.md, "Perks the autopilot cannot use").
## A profile is a small policy layered on `GameBot.live_life` that adds only the actions one family of perks needs, through the same core calls the screens
## use (no new rules, so what it measures is what a player gets). `GameBot.live_life(d, hook)` calls the profile's hook before each decision, and
## `GameBot.on_fight_end` / `flee_below` carry the two things a profile needs from a fight; with no profile set every one of them is off and the autopilot plays
## bit for bit as before (tests/test_game_profiles.gd compares).
##
## **Effort** (`actions`) is the count of the player actions a profile spends (a salvage, a craft, a dig, a forage, a build, a purchase, a flight). **Net worth** is
## the gold-equivalent of what a life leaves: the purse, the family's materials and essences at the shop's unit prices, the pack and what is worn at their sell
## price, kept creatures at their sell price, built pieces at their *list* cost (so a calling that builds for less shows the saving) and potions at their price.
## `finish` gives the life's net-worth gain and its effort. Dice: the profiles draw none of the dynasty's (the core calls they make are keyed on the seed), but
## their actions change what the autopilot later buys and meets, so a profile run is a fresh draw of lives, as a calling's is.
class_name GameProfile
extends RefCounted

const IDS := ["forge", "miner", "builder", "farmer", "breeder", "forager", "fleer", "trialist"]
const ESSENCE_UNIT := 40.0   # gold an essence is counted at, per tier of its affix (the Enchanter's own price: data/shops/shops.json is not read here)
const FLEE_BELOW := 0.35     # the fleer's rule: try to run under this share of health


static func has(id: String) -> bool:
	return id in IDS


## The state of one life's profile: {id, steps, actions, worth0, shaft, forage_i, house_i}.
static func start(d: GameDynasty, id: String) -> Dictionary:
	return {"id": id, "steps": 0, "actions": 0, "worth0": net_worth(d), "shaft": 0, "forage_i": 0, "house_i": 0, "fled": 0, "trials": 0, "tried": 0, "passed": [], "paid": 0, "hours": 0.0, "hops": 0, "clock": 0, "age0": float(d.heir.age)}


## Sets the hooks for a life of this profile and returns the Callable to give `GameBot.live_life`. `detach` puts everything back.
static func attach(ctx: Dictionary) -> Callable:
	GameBot.flee_below = FLEE_BELOW if str(ctx["id"]) == "fleer" else 0.0
	GameBot.on_fight_end = func(d, foes, result): _after_fight(d, ctx, foes, str(result))
	return func(d): hook(d, ctx)


static func detach() -> void:
	GameBot.flee_below = 0.0
	GameBot.on_fight_end = Callable()


## What the life gained and what it cost in actions: {gain (gold-equivalent), actions}.
static func finish(d: GameDynasty, ctx: Dictionary) -> Dictionary:
	return {"gain": net_worth(d) - float(ctx["worth0"]), "actions": int(ctx["actions"]), "trials": int(ctx["trials"]), "tried": int(ctx["tried"]), "paid": int(ctx["paid"]), "hours": float(ctx["hours"]), "hops": int(ctx["hops"]), "clock": int(ctx["clock"])}


# ---------------------------------------------------------------- net worth

static func net_worth(d: GameDynasty) -> float:
	var h := d.heir
	var w := float(h.gold)
	for m in GameMaterials.ids():
		w += float(GameCraft.have(d, str(m))) * GameShops.unit_price(str(m))
	for a in GameCraft.essences(d):
		w += float(GameCraft.essence_have(d, str(a))) * ESSENCE_UNIT * float(GameLoot.data()["_affix"].get(str(a), {}).get("min_tier", 1))
	var seen := {}
	for id in h.inventory:
		w += float(GameItems.sell_price(d, str(id)))
	for slot in h.equipment:
		if str(h.equipment[slot]) != "":
			w += float(GameItems.sell_price(d, str(h.equipment[slot])))
	for e in d.roster:
		w += float(GameRanch.sell_price(e, d))
	for k in d.built:
		var p: Dictionary = GameBuild.pieces().get(str(d.built[k]), {})
		if not p.is_empty():
			for m in p["cost"]:
				w += float(p["cost"][m]) * GameShops.unit_price(str(m))
			w += float(p["gold"])
	w += float(h.potions) * float(d.potion_price())
	return w


# ---------------------------------------------------------------- the hook

static func hook(d: GameDynasty, ctx: Dictionary) -> void:
	ctx["steps"] = int(ctx["steps"]) + 1
	var n := int(ctx["steps"])
	match str(ctx["id"]):
		"forge":
			if n % 5 == 0:
				_forge(d, ctx)
		"miner":
			if n % 3 == 0:
				_mine(d, ctx)
		"forager":
			if n % 3 == 0:
				_forage(d, ctx)
		"builder":
			if n % 2 == 0:
				_forage(d, ctx)
			if n % 9 == 0:
				_mine(d, ctx)   # the iron a house's frame wants
			if n % 6 == 0:
				_build(d, ctx)
		"farmer":
			if n % 8 == 0:
				_farm(d, ctx, false)
		"breeder":
			if n % 8 == 0:
				_farm(d, ctx, true)
		"trialist":
			if n % 4 == 0:
				_trial(d, ctx)


static func _after_fight(d: GameDynasty, ctx: Dictionary, foes: Array, result: String) -> void:
	if str(ctx["id"]) == "forge" and result == "victory":
		# what the screens ask for when the dead are searched: the creatures' parts and a chance of a made piece
		GameCraft.after_search(d, foes, "hunt")
		GameLoot.after_search(d, foes, "search")
	if str(ctx["id"]) == "fleer" and result == "fled":
		ctx["actions"] = int(ctx["actions"]) + 1


static func _act(ctx: Dictionary, n: int = 1) -> void:
	ctx["actions"] = int(ctx["actions"]) + n


# ---------------------------------------------------------------- forge

## At a town forge: break up the made pieces in the pack, make the dearest piece the stores allow, brew the potion when there are herbs.
static func _forge(d: GameDynasty, ctx: Dictionary) -> void:
	if not d.world.has_service(str(GameCraft.setting("needs_service"))):
		return
	for id in d.heir.inventory.duplicate():
		if GameLoot.is_generated(str(id)) and str(id) not in d.heir.equipment.values():
			GameCraft.salvage(d, str(id))
			_act(ctx)
	var best := {}
	var best_price := 0
	for f in GameLoot.data()["forms"]:
		var form_id := str(f["id"])
		for m in GameCraft.materials_for(form_id):
			if GameCraft.have(d, str(m)) <= 0:
				continue
			var chosen: Array = []
			for a in GameCraft.essences_for(form_id, str(m)):
				if chosen.size() < 2 and GameCraft.essence_have(d, str(a)) > 0:
					chosen.append(str(a))
			var p := GameCraft.plan(d, form_id, str(m), chosen)
			if bool(p["ok"]) and int(p["item"]["price"]) > best_price:
				best_price = int(p["item"]["price"])
				best = {"form": form_id, "material": str(m), "chosen": chosen}
	if not best.is_empty():
		GameCraft.craft(d, str(best["form"]), str(best["material"]), best["chosen"])
		_act(ctx)
	for b in GameCraft.brews():
		if bool(GameCraft.brew_plan(d, str(b))["ok"]):
			GameCraft.brew(d, str(b))
			_act(ctx)
			break


# ---------------------------------------------------------------- miner

## One strike down a shaft at the homestead's edge; the next column when one is as deep as the mine allows. Stops while the heir is hurt.
static func _mine(d: GameDynasty, ctx: Dictionary) -> void:
	if float(d.heir.hp) < 0.6 * float(d.heir.max_hp()):
		return
	var base := GameBuild.base()
	if base.is_empty():
		return
	var site := GameWorldGen.MINE_SITE
	var x := int(base["x"]) + int(ctx["shaft"])
	var z := int(base["z"])
	var depth := 0
	while depth <= int(GameMine.setting("max_depth")) and GameMine.is_dug(d, site, x, depth, z):
		depth += 1
	if depth > int(GameMine.setting("max_depth")):
		ctx["shaft"] = int(ctx["shaft"]) + 1
		return
	var out := GameMine.dig(d, site, x, depth, z)
	if bool(out["ok"]):
		GameMine.hazard(d, site, x, depth, z)
		_act(ctx)
	else:
		ctx["shaft"] = int(ctx["shaft"]) + 1


# ---------------------------------------------------------------- forager (and the builder's materials)

## Forages at points round the homestead until one has a node in reach (a few tries a call).
static func _forage(d: GameDynasty, ctx: Dictionary) -> void:
	var base := GameBuild.base()
	if base.is_empty():
		return
	for t in 8:
		var i := int(ctx["forage_i"])
		ctx["forage_i"] = i + 1
		var ang := float(i) * 0.7
		var r := 14.0 + float(i % 5) * 5.0
		var x := int(round(float(base["x"]) + cos(ang) * r))
		var z := int(round(float(base["z"]) + sin(ang) * r))
		if not GameWorldGen.in_bounds(x, z):
			continue
		if bool(GameForage.forage(d, x, z)["ok"]):
			_act(ctx)
			return


# ---------------------------------------------------------------- builder

## Raises the next small house (3 by 3) of the homestead plot when the stores and the purse allow: a grid of doors inside the family's ground.
static func _build(d: GameDynasty, ctx: Dictionary) -> void:
	var base := GameBuild.base()
	if base.is_empty():
		return
	var i := int(ctx["house_i"])
	var door_x := int(base["x"]) - 5 + (i % 3) * 5
	var door_z := int(base["z"]) - 2 + (i / 3) * 5
	var cost := GameBuild.house_cost(3, 3)
	for m in cost["materials"]:
		if GameCraft.have(d, str(m)) < int(cost["materials"][m]):
			return
	if d.heir.gold < int(cost["gold"]) * 2:
		return
	var out := GameBuild.build_house(d, 3, 3, door_x, door_z)
	if bool(out["ok"]):
		ctx["house_i"] = i + 1
		_act(ctx)
	else:
		ctx["house_i"] = i + 1   # a spot that cannot be built on: try the next


# ---------------------------------------------------------------- farmer and breeder

## At a market town: buy the cheapest young animal while there is room and the purse is comfortable. The breeder also sets adults to breed and sells
## the young it has no pen for.
static func _farm(d: GameDynasty, ctx: Dictionary, breed: bool) -> void:
	var cheapest := ""
	for s in GameFarm.market_species():
		if cheapest == "" or GameFarm.price(str(s)) < GameFarm.price(cheapest):
			cheapest = str(s)
	if cheapest != "" and d.heir.gold >= GameFarm.price(cheapest) * 5 and GameFarm.why_not_buy(d, cheapest) == "":
		if GameFarm.buy(d, cheapest) != "":
			_act(ctx)
	if not breed:
		return
	for e in d.roster:
		if str(e.get("stage")) == "adult" and not bool(e.get("breeding", false)) and GameBreeding.can_set(e):
			if GameBreeding.set_breeding(d, int(e["id"]), true):
				_act(ctx)
	if GameRoster.full(d):
		for e in d.roster:
			if str(e.get("stage")) == "young" and not bool(e.get("breeding", false)):
				GameRanch.sell(d, int(e["id"]))
				_act(ctx)
				break


# ---------------------------------------------------------------- trialist

## One move toward the next trial of the realms, through the calls the Trials screen makes (GameTrials): with one under way, let its hours pass and
## finish it; else begin one that is ready, do the next step of the way in when the heir stands where it is done, or take one road toward the place the
## step asks for. It takes the trials in the listing's order (lowest level first), skips the two that are won by a fight, and passes over a step it cannot
## pay or a level it has not reached (the autopilot's life goes on and the step is tried again later). Travel costs the years the road takes, the offering
## its gold, the trial its hours on the world clock: that is the price the profile pays, and it is counted in its effort.
static func _trial(d: GameDynasty, ctx: Dictionary) -> void:
	if d.battle != null or d.state != "life":
		return
	if not GameTrials.active(d).is_empty():
		var id := str(GameTrials.active(d)["id"])
		if bool(GameTrials.trial(id).get("fight", false)):
			GameTrials.leave(d)   # never one the bot cannot fight; (begin is never offered for them below)
			return
		if GameTrials.remaining(d) > 0.0:
			ctx["hours"] = float(ctx["hours"]) + GameTrials.remaining(d)
			var g0 := d.heir.gold
			GameTrials.wait_out(d)
			ctx["clock"] = int(ctx["clock"]) + (g0 - d.heir.gold)   # what the world's clock took (or gave) while the hours went
			_act(ctx)
			if d.state != "life" or not GameTrials.active(d).has("id"):
				return
		var gold_before := d.heir.gold
		GameTrials.finish(d)
		ctx["paid"] = int(ctx["paid"]) + maxi(0, gold_before - d.heir.gold)   # a failed try's cost
		_act(ctx)
		ctx["tried"] = int(ctx["tried"]) + 1
		if GameTrials.done(d.heir, id):
			ctx["trials"] = int(ctx["trials"]) + 1
			(ctx["passed"] as Array).append(id)
		return
	for t in GameTrials.listing(d):
		if bool(t["fight"]):
			continue
		var id := str(t["id"])
		var gate: Dictionary = GameTrials.trial(id)["gate"]
		if d.heir.level < int(gate.get("level", 1)) or (gate.has("classes") and d.heir.class_id not in gate["classes"]) or (gate.has("trial") and not GameTrials.done(d.heir, str(gate["trial"]))):
			continue   # a way in is not paid for a trial the heir could not begin
		match str(t["status"]):
			"ready":
				GameTrials.start(d, id)
				_act(ctx)
				return
			"way":
				if GameTrials.step_block(d, id) == "":
					var before := d.heir.gold
					GameTrials.do_step(d, id)
					ctx["paid"] = int(ctx["paid"]) + maxi(0, before - d.heir.gold)   # an offering
					_act(ctx)
					return
				var s := GameTrials.next_step(d, id)
				if str(s.get("kind", "")) == "visit" and d.world.location != str(s["place"]):
					var route := d.world.route_to(str(s["place"]), d.flags)
					if not route.is_empty():
						var g1 := d.heir.gold
						d.travel(str(route[0]))
						ctx["clock"] = int(ctx["clock"]) + (g1 - d.heir.gold)
						ctx["hops"] = int(ctx["hops"]) + 1
						_act(ctx)
						return
