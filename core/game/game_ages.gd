## Ages and the long count. The world cycles through Ages of age_length generations, and a
## dynasty's saga ends when the heir of generation max_generations dies. Content gates (creatures,
## legends, quests, events, companions) read the generation within the Age
## (GameDynasty.era_gen); every scaling keeps the true generation, so each Age is stronger.
##
## History: the founder's record and the most recent history_full_keep heirs stay in full in
## GameDynasty.history. Older heirs are folded into one summary per Age, and `hall` keeps the
## greatest heirs of the whole saga, so a save stays small however long the house lasts.
## Summary: {age, from, to, heirs, greatest, legends: [{id, by, gen, times?}], causes: {cause: n}}.
## Tunables and text live in data/ages/ages.json.
class_name GameAges
extends RefCounted

var summaries: Array = []   # oldest Age first: the heirs folded out of the full history
var hall: Array = []        # the greatest heirs of the saga, highest level first (see _brief)


# ---------------------------------------------------------------- data

static func settings() -> Dictionary:
	GameData.load_all()
	return GameData.ages.get("settings", {})


static func setting(key: String) -> Variant:
	return settings()[key]


static func text(key: String, values: Dictionary = {}) -> String:
	GameData.load_all()
	return str(GameData.ages.get("text", {}).get(key, "")).format(values)


static func age_length() -> int:
	return maxi(1, int(setting("age_length")))


static func max_generations() -> int:
	return maxi(1, int(setting("max_generations")))


# ---------------------------------------------------------------- the long count

## Generation within its Age, 1..age_length.
static func era_of(gen: int) -> int:
	return (maxi(1, gen) - 1) % age_length() + 1


@warning_ignore("integer_division")
static func age_of(gen: int) -> int:
	return (maxi(1, gen) - 1) / age_length() + 1


static func is_legend(creature_id: String) -> bool:
	for c in GameData.creatures:
		if c["id"] == creature_id:
			return c.get("boss", false)
	return false


# ---------------------------------------------------------------- a new Age, and the end

## The generation just begun opens a new Age: the legends rise again in their lairs. Flags,
## heirlooms, echoes and companion lines carry on; once-only events and story quests look at
## the Age they were last seen in (GameEvents.seen, GameQuests.is_posted).
static func begin_age(d: GameDynasty, msgs: Array) -> void:
	wake_legends(d)
	msgs.append(text("age_begins", {"age": GameText.num(d.age_number()), "house": d.dynasty_name}))


## Legends slain in an earlier Age are back in their lairs. A save from before the Ages may
## already be past the turn of one, so loading wakes them too.
static func wake_legends(d: GameDynasty) -> void:
	for id in d.slain_bosses.keys():
		if age_of(int(d.slain_bosses[id])) < d.age_number():
			d.slain_bosses.erase(id)


## The heir of the last generation has died: no one succeeds, and the save is marked finished.
static func end_saga(d: GameDynasty, msgs: Array) -> void:
	d.state = "ended"
	d.candidates = []
	msgs.append(text("saga_ends", {"heir": d.heir.name, "house": d.dynasty_name, "generations": count(d.gen, "generation"), "ages": count(d.age_number(), "Age")}))


## "1 Age", "910 Ages", "999,999 generations".
static func count(n: int, word: String) -> String:
	return "%s %s%s" % [GameText.num(n), word, "" if n == 1 else "s"]


## For tests and tools: moves the living heir's family to generation `to` as if the years between
## had passed off-screen. Landing in a later Age wakes the legends, as a new Age does.
static func jump_to(d: GameDynasty, to: int) -> void:
	to = clampi(to, 1, max_generations())
	if age_of(to) != age_of(d.gen):
		d.slain_bosses.clear()
	d.gen = to
	d.heir.gen = to
	d.heir.refresh_derived()
	d.heir.full_heal()
	d.party.sync(d)


# ---------------------------------------------------------------- history

## Every heir's record, as they die: ranked for the hall, then the oldest are folded.
func on_death(d: GameDynasty, rec: Dictionary) -> void:
	note(rec)
	fold(d)


## Keeps the greatest heirs of the saga: highest level first, the earlier heir winning a tie.
func note(rec: Dictionary) -> void:
	hall.append(_brief(rec))
	hall.sort_custom(func(a, b): return _ranks_above(a, b))
	var keep := maxi(0, int(setting("hall_of_fame")))
	if hall.size() > keep:
		hall.resize(keep)


## Folds the records past the most recent history_full_keep into their Age's summary. The
## founder's record (history[0]) stays for good: events still speak the founder's name.
func fold(d: GameDynasty) -> void:
	var extra := d.history.size() - 1 - maxi(1, int(setting("history_full_keep")))
	if extra <= 0:
		return
	for i in range(1, 1 + extra):
		_add(summaries, d.history[i])
	d.history = [d.history[0]] + d.history.slice(1 + extra)


## Every Age the house has lived through, oldest first, counting the heirs kept in full too.
func age_rows(d: GameDynasty) -> Array:
	var rows: Array = summaries.duplicate(true)
	for rec in d.history:
		_add(rows, rec)
	return rows


## Legend id -> times slain, over the whole saga.
func legend_totals(d: GameDynasty) -> Dictionary:
	var out := {}
	for row in age_rows(d):
		for l in row["legends"]:
			out[l["id"]] = int(out.get(l["id"], 0)) + int(l.get("times", 1))
	return out


## Cause of death -> heirs, over the whole saga.
func cause_totals(d: GameDynasty) -> Dictionary:
	var out := {}
	for row in age_rows(d):
		for c in row["causes"]:
			out[c] = int(out.get(c, 0)) + int(row["causes"][c])
	return out


func folded_heirs() -> int:
	var n := 0
	for s in summaries:
		n += int(s["heirs"])
	return n


static func _ranks_above(a: Dictionary, b: Dictionary) -> bool:
	if int(a["level"]) != int(b["level"]):
		return int(a["level"]) > int(b["level"])
	return int(a["gen"]) < int(b["gen"])


## The few facts a summary or the hall keeps about one heir.
static func _brief(rec: Dictionary) -> Dictionary:
	return {"name": str(rec.get("name", "")), "level": int(rec.get("level", 1)), "gen": int(rec.get("gen", 1)),
		"class_id": str(rec.get("class_id", "warrior")), "race_id": str(rec.get("race_id", "human"))}


## Adds one heir's record to the summary of their Age in `rows` (oldest Age first).
static func _add(rows: Array, rec: Dictionary) -> void:
	var g := int(rec.get("gen", 1))
	var age := age_of(g)
	var row: Dictionary = {}
	var at := 0
	for i in range(rows.size() - 1, -1, -1):
		if int(rows[i]["age"]) <= age:
			if int(rows[i]["age"]) == age:
				row = rows[i]
			at = i + 1
			break
	if row.is_empty():
		row = {"age": age, "from": g, "to": g, "heirs": 0, "greatest": {}, "legends": [], "causes": {}}
		rows.insert(at, row)
	row["from"] = mini(int(row["from"]), g)
	row["to"] = maxi(int(row["to"]), g)
	row["heirs"] = int(row["heirs"]) + 1
	var me := _brief(rec)
	if (row["greatest"] as Dictionary).is_empty() or _ranks_above(me, row["greatest"]):
		row["greatest"] = me
	var cause := str(rec.get("cause", "old age"))
	row["causes"][cause] = int(row["causes"].get(cause, 0)) + 1
	var kills: Dictionary = rec.get("kills", {})
	var ids: Array = kills.keys()
	ids.sort()   # a reloaded save lists kills in another order; the summary must not depend on it
	for id in ids:
		if not is_legend(str(id)):
			continue
		var seen := false
		for l in row["legends"]:
			if l["id"] == id:
				l["times"] = int(l.get("times", 1)) + int(kills[id])
				seen = true
		if not seen:
			var entry := {"id": str(id), "by": me["name"], "gen": g}
			if int(kills[id]) > 1:
				entry["times"] = int(kills[id])
			# In the order they fell: the founder's record joins its Age's summary last.
			var at_l: int = (row["legends"] as Array).size()
			while at_l > 0 and int(row["legends"][at_l - 1]["gen"]) > g:
				at_l -= 1
			row["legends"].insert(at_l, entry)


# ---------------------------------------------------------------- save / load & checks

func to_dict() -> Dictionary:
	return {"summaries": summaries, "hall": hall}


## `d` is the dynasty being loaded, its history already read. A save from before the Ages has no
## summaries: its whole history is ranked for the hall, then folded like any other.
static func from_dict(v: Variant, d: GameDynasty) -> GameAges:
	var a := GameAges.new()
	if typeof(v) == TYPE_DICTIONARY:
		a.summaries = GameDynasty._ints(Array(v.get("summaries", [])))
		a.hall = GameDynasty._ints(Array(v.get("hall", [])))
	else:
		for rec in d.history:
			a.note(rec)
	a.fold(d)
	return a


## Problems with the Ages data, or content whose generation window does not fit in one Age.
static func validate() -> Array:
	GameData.load_all()
	var bad: Array = []
	for k in ["max_generations", "age_length", "history_full_keep", "hall_of_fame", "party_fallen_kept"]:
		if not settings().has(k) or int(settings()[k]) < 1:
			bad.append("settings.%s must be a whole number of at least 1" % k)
	for k in ["age_begins", "heirloom_held", "saga_ends", "last_heir", "folded"]:
		if text(k) == "":
			bad.append("text.%s is missing" % k)
	var span := age_length()
	var gated: Array = []
	for c in GameData.creatures:
		gated.append(["creature %s" % c["id"], c])
	for q in GameData.quests:
		gated.append(["quest %s" % q["id"], q.get("requires", {})])
	for e in GameData.events:
		gated.append(["event %s" % e["id"], e.get("requires", {})])
	for c in GameData.companions:
		gated.append(["companion %s" % c["id"], c.get("requires", {})])
	for g in gated:
		var lo := int(g[1].get("min_gen", 1))
		var hi := int(g[1].get("max_gen", span))
		if lo < 1 or hi > span or lo > hi:
			bad.append("%s: generations %d-%d do not fit in an Age of %d" % [g[0], lo, hi, span])
	return bad
