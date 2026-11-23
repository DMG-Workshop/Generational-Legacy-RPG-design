## The balance harness's logic, apart from its command line (tools/balance_harness.gd), so a test can
## cover it: playing batches, counting battle deaths and judging them against the roadmap's band.
extends RefCounted

const BAND_LOW := 3.0
const BAND_HIGH := 7.0
const BLOODLINE := "faetouched"
const SLAIN := "slain in battle"   # the cause GameDynasty._die is given when a defeat kills the heir


## One dynasty per race given, the founder's class rotating through the starting classes. Returns
## {"total": totals, "by_race": {race id: totals}}, where totals are {lives, slain, level, age} and
## `by_race` is keyed by the race of each heir (hybrids appear through marriages). Totals also hold the gold,
## kills and battles won at death (sums), the lives that `carried` a subclass, and the dynasties played and ended.
## `subclass` founds each dynasty in that calling ("" for none, which plays exactly as before); it passes down at
## the game's own inheritance chance. With `keep` every new heir is also founded in it, so every life carries it.
static func play_batch(base: int, races: Array, gens: int, subclass: String = "", keep: bool = false, profile: String = "") -> Dictionary:
	GameData.load_all()
	var total := blank()
	var by_race := {}
	var classes := GameData.starting_ids(GameData.classes)
	for ri in races.size():
		var d := GameDynasty.new_game(base * 1000 + ri, "", classes[(ri + base) % classes.size()], BLOODLINE, str(races[ri]), GameSex.MALE, subclass)
		total["dynasties"] += 1
		for g in gens:
			var carried := 1 if d.heir != null and d.heir.subclass != "" else 0
			var ctx := {}
			if profile != "":   # a profile bot (GameProfile): its extra actions, and what the life gained and cost
				ctx = GameProfile.start(d, profile)
				GameBot.live_life(d, GameProfile.attach(ctx))
				GameProfile.detach()
			else:
				GameBot.live_life(d)
			var rec: Dictionary = d.last_death
			if profile != "":
				var fin := GameProfile.finish(d, ctx)
				rec = rec.duplicate()
				rec["profile_gain"] = float(fin["gain"])
				rec["profile_actions"] = int(fin["actions"])
			var race := str(rec.get("race_id", races[ri]))
			if not by_race.has(race):
				by_race[race] = blank()
			record(total, rec, carried)
			record(by_race[race], rec, carried)
			if d.state != "succession":
				total["ended"] += 1
				break
			GameBot.choose_best(d)
			if keep and subclass != "" and d.heir != null:
				GameSubclass.found(d.heir, subclass)
	return {"total": total, "by_race": by_race}


## Counts one finished life (a GameDynasty death record) into `totals`; `carried` is 1 when that heir had a subclass.
static func record(totals: Dictionary, rec: Dictionary, carried: int = 0) -> void:
	totals["lives"] += 1
	totals["level"] += float(rec.get("level", 0))
	totals["age"] += float(rec.get("age", 0))
	totals["gold"] += float(rec.get("gold", 0))
	totals["wins"] += float(rec.get("battles_won", 0))
	var kills: Variant = rec.get("kills", {})
	if typeof(kills) == TYPE_DICTIONARY:
		for k in kills:
			totals["kills"] += float(kills[k])
	totals["carried"] += carried
	totals["ge"] += float(rec.get("profile_gain", 0.0))
	totals["actions"] += float(rec.get("profile_actions", 0))
	if str(rec.get("cause", "")) == SLAIN:
		totals["slain"] += 1


## A subclass argument the harness accepts: "" (none), one of the twenty ids, or "all" (the sweep, read by the harness).
static func valid_subclass(id: String) -> bool:
	return id == "" or id == "all" or GameSubclass.has(id)


## "1-12" or "1,5,9" or a mix such as "1-3,9".
static func parse_seeds(text: String) -> Array:
	var out: Array = []
	for part in text.split(",", false):
		if "-" in part:
			var ends := part.split("-", false)
			if ends.size() == 2:
				out.append_array(seed_range(int(ends[0]), int(ends[1])))
		else:
			out.append(int(part))
	return out


static func seed_range(first: int, last: int) -> Array:
	var out: Array = []
	for s in range(first, last + 1):
		out.append(s)
	return out


static func blank() -> Dictionary:
	return {"lives": 0, "slain": 0, "level": 0.0, "age": 0.0, "gold": 0.0, "kills": 0.0, "wins": 0.0, "carried": 0, "dynasties": 0, "ended": 0, "ge": 0.0, "actions": 0.0}


static func add(into: Dictionary, from: Dictionary) -> void:
	for k in into:
		into[k] += from[k]


## The means that go with a share: gold at death, kills and battles won per life, the share of lives that
## carried a subclass and the generations reached per dynasty.
static func detail(t: Dictionary) -> String:
	var n := maxf(1.0, float(t["lives"]))
	return "gold %6.0f, kills %5.1f, wins %5.1f, carried %3.0f%%, %4.1f gens/dynasty" % [float(t["gold"]) / n, float(t["kills"]) / n, float(t["wins"]) / n, 100.0 * float(t["carried"]) / n, float(t["lives"]) / maxf(1.0, float(t["dynasties"]))]


## What a profile's lives gained and cost per life: gold-equivalent net-worth gain (GameProfile.net_worth), actions spent, and the return on effort (gain per action).
static func profile_detail(t: Dictionary) -> String:
	var n := maxf(1.0, float(t["lives"]))
	var a := float(t["actions"]) / n
	return "gain %6.0f GE, effort %5.1f actions, %5.1f GE per action" % [float(t["ge"]) / n, a, (float(t["ge"]) / n) / maxf(1.0, a)]


## Percent of lives that ended slain in battle.
static func share(t: Dictionary) -> float:
	return 100.0 * float(t["slain"]) / maxf(1.0, float(t["lives"]))


static func line(t: Dictionary) -> String:
	var n := maxf(1.0, float(t["lives"]))
	return "%4d lives, slain %3d (%4.1f%%), mean level %5.0f, mean age %4.0f" % [int(t["lives"]), int(t["slain"]), share(t), float(t["level"]) / n, float(t["age"]) / n]


## "IN BAND", "BELOW BAND", "ABOVE BAND" or "NO LIVES PLAYED" for a share of lives. The edges are in the band.
static func verdict(percent: float, lives: int) -> String:
	if lives <= 0:
		return "NO LIVES PLAYED"
	if percent < BAND_LOW:
		return "BELOW BAND"
	if percent > BAND_HIGH:
		return "ABOVE BAND"
	return "IN BAND"


## The 95% Wilson range for k of n, in percent (x low, y high).
static func wilson(k: int, n: int) -> Vector2:
	if n <= 0:
		return Vector2.ZERO
	var z := 1.96
	var p := float(k) / float(n)
	var denom := 1.0 + z * z / n
	var centre := (p + z * z / (2.0 * n)) / denom
	var half := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	return Vector2(100.0 * (centre - half), 100.0 * (centre + half))
