## The balance harness's logic, apart from its command line (tools/balance_harness.gd), so a test can
## cover it: playing batches, counting battle deaths and judging them against the roadmap's band.
extends RefCounted

const BAND_LOW := 3.0
const BAND_HIGH := 7.0
const BLOODLINE := "faetouched"
const SLAIN := "slain in battle"   # the cause GameDynasty._die is given when a defeat kills the heir


## One dynasty per race given, the founder's class rotating through the starting classes. Returns
## {"total": totals, "by_race": {race id: totals}}, where totals are {lives, slain, level, age} and
## `by_race` is keyed by the race of each heir (hybrids appear through marriages).
static func play_batch(base: int, races: Array, gens: int) -> Dictionary:
	GameData.load_all()
	var total := blank()
	var by_race := {}
	var classes := GameData.starting_ids(GameData.classes)
	for ri in races.size():
		var d := GameDynasty.new_game(base * 1000 + ri, "", classes[(ri + base) % classes.size()], BLOODLINE, str(races[ri]))
		for g in gens:
			GameBot.live_life(d)
			var rec: Dictionary = d.last_death
			var race := str(rec.get("race_id", races[ri]))
			if not by_race.has(race):
				by_race[race] = blank()
			record(total, rec)
			record(by_race[race], rec)
			if d.state != "succession":
				break
			GameBot.choose_best(d)
	return {"total": total, "by_race": by_race}


## Counts one finished life (a GameDynasty death record) into `totals`.
static func record(totals: Dictionary, rec: Dictionary) -> void:
	totals["lives"] += 1
	totals["level"] += float(rec.get("level", 0))
	totals["age"] += float(rec.get("age", 0))
	if str(rec.get("cause", "")) == SLAIN:
		totals["slain"] += 1


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
	return {"lives": 0, "slain": 0, "level": 0.0, "age": 0.0}


static func add(into: Dictionary, from: Dictionary) -> void:
	for k in into:
		into[k] += from[k]


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
