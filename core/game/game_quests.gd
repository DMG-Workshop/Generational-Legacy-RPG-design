## Side quests offered on town notice boards, driven by the dynasty's story flags.
## Unfinished quests are family obligations: they carry over to the next heir.
## Quest content lives in data/quests/quests.json; objectives are kill / visit / flag.
class_name GameQuests
extends RefCounted

var active: Array = []        # [{"id", "progress", "gen": generation taken up, "by": heir who took it}]
var done: Array = []          # quest ids the family has completed
var record: Dictionary = {}   # quest id -> {"times": int, "gen": generation of the last turn-in}


# ---------------------------------------------------------------- data

static func def(id: String) -> Dictionary:
	GameData.load_all()
	for q in GameData.quests:
		if q["id"] == id:
			return q
	return {}


static func kind(q: Dictionary) -> String:
	return str(q.get("objective", {}).get("type", ""))


## Creature ids a kill objective accepts (one id or a list in the data).
static func targets(q: Dictionary) -> Array:
	var t: Variant = q.get("objective", {}).get("target", [])
	return (t as Array) if t is Array else [str(t)]


static func goal(q: Dictionary) -> int:
	if kind(q) == "kill":
		return maxi(1, int(q["objective"].get("count", 1)))
	return 1


static func place_name(id: String) -> String:
	return str(GameWorld.place(id).get("name", id))


static func _creature(id: String) -> Dictionary:
	for c in GameData.creatures:
		if c["id"] == id:
			return c
	return {}


## A creature can still be met in this generation: in its era of the Age, and a legend not yet slain.
static func roams(d: GameDynasty, creature_id: String) -> bool:
	var c := _creature(creature_id)
	var era := d.era_gen()
	if c.is_empty() or era < int(c["min_gen"]) or era > int(c["max_gen"]):
		return false
	return not (c.get("boss", false) and d.slain_bosses.has(creature_id))


## A kill quest is only worth posting while something it asks for still roams.
static func achievable(d: GameDynasty, q: Dictionary) -> bool:
	if kind(q) != "kill":
		return true
	return targets(q).any(func(t): return roams(d, t))


static func objective_text(q: Dictionary) -> String:
	var o: Dictionary = q.get("objective", {})
	if o.has("label"):
		return str(o["label"]).format({"count": goal(q)})
	match kind(q):
		"kill":
			var names: Array = targets(q).map(func(t): return str(_creature(t).get("name", t)))
			var where := " in %s" % place_name(str(o["place"])) if o.has("place") else ""
			return "Slay %s x%d%s" % [" or ".join(names), goal(q), where]
		"visit":
			return "Reach %s" % place_name(str(o.get("target", "")))
		"flag":
			return "See it done: %s" % str(o.get("flag", "")).capitalize()
	return ""


static func reward_gold(d: GameDynasty, q: Dictionary) -> int:
	var base := float(q.get("reward", {}).get("gold", 0))
	return int(round(base * GameData.enemy_scale(d.gen) * float(GameData.bal("quest_gold_mult"))))


static func reward_xp(d: GameDynasty, q: Dictionary) -> int:
	var base := float(q.get("reward", {}).get("xp", 0))
	return int(round(base * GameData.xp_level_scale(d.heir.level) * float(GameData.bal("quest_xp_mult"))))


## "66 gold, 35 XP, Prayer Beads" at the current generation and heir level.
static func reward_text(d: GameDynasty, q: Dictionary) -> String:
	var parts: Array = []
	var g := reward_gold(d, q)
	var x := reward_xp(d, q)
	if g > 0:
		parts.append("%s gold" % GameText.num(g))
	if x > 0:
		parts.append("%s XP" % GameText.num(x))
	for it in q.get("reward", {}).get("items", []):
		parts.append(str(GameItems.item_def(it).get("name", it)))
	if q.get("reward", {}).has("echo"):
		parts.append("renown")
	return ", ".join(parts) if not parts.is_empty() else "thanks"


# ---------------------------------------------------------------- the house's log

func entry(id: String) -> Dictionary:
	for e in active:
		if e["id"] == id:
			return e
	return {}


func is_active(id: String) -> bool:
	return not entry(id).is_empty()


func is_complete(e: Dictionary) -> bool:
	return int(e["progress"]) >= goal(def(e["id"]))


func times_done(id: String) -> int:
	return int(record.get(id, {}).get("times", 0))


func total_done() -> int:
	var n := 0
	for id in record:
		n += int(record[id]["times"])
	return n


## Posted on its board this generation: era of the Age, story flags, cooldown, and quarry still
## about. A notice done once goes up again in a later Age, unless its deed is "lasting".
## Heir level is not checked here (the board shows those notices as out of reach).
func is_posted(d: GameDynasty, q: Dictionary) -> bool:
	var id: String = q["id"]
	var req: Dictionary = q.get("requires", {})
	var era := d.era_gen()
	if is_active(id) or era < int(req.get("min_gen", 1)):
		return false
	if req.has("max_gen") and era > int(req["max_gen"]):
		return false
	for f in req.get("flags", []):
		if not d.flags.has(f):
			return false
	for f in req.get("not_flags", []):
		if d.flags.has(f):
			return false
	if record.has(id):
		var last := int(record[id]["gen"])
		if not q.get("repeatable", false):
			if q.get("lasting", false) or GameAges.age_of(last) >= d.age_number():
				return false
		elif d.gen < last + int(q.get("cooldown", 1)):
			return false
	return achievable(d, q)


## Notices on `town`'s board right now.
func postings(d: GameDynasty, town: String) -> Array:
	return GameData.quests.filter(func(q): return q["giver"] == town and is_posted(d, q))


## Why the heir cannot take up quest `id` here and now, or "" if they can.
func accept_block(d: GameDynasty, id: String) -> String:
	var q := def(id)
	if q.is_empty():
		return "No such notice."
	if is_active(id):
		return "The house has already taken this up."
	if d.world.location != q["giver"] or not d.world.has_service("board"):
		return "This notice hangs in %s." % place_name(q["giver"])
	if not is_posted(d, q):
		return "This notice is not posted now."
	var max_active := int(GameData.bal("quest_max_active"))
	if active.size() >= max_active:
		return "The house already carries %d obligations." % max_active
	var lv := int(q.get("requires", {}).get("min_level", 1))
	if d.heir.level < lv:
		return "Needs level %d." % lv
	return ""


func accept(d: GameDynasty, id: String) -> Array:
	var why := accept_block(d, id)
	if why != "":
		return [why]
	var q := def(id)
	var e := {"id": id, "progress": 0, "gen": d.gen, "by": d.heir.name}
	active.append(e)
	var msgs: Array = ["%s takes down the notice: %s. %s." % [d.heir.name, q["name"], objective_text(q)]]
	# A deed the house has already done counts at once.
	var o: Dictionary = q["objective"]
	if (kind(q) == "flag" and d.flags.has(o.get("flag", ""))) or (kind(q) == "visit" and d.world.location == o.get("target", "")):
		e["progress"] = 1
		msgs.append("It is already done. Claim the reward here.")
	for m in msgs:
		d._say(m)
	return msgs


func abandon(d: GameDynasty, id: String) -> Array:
	var e := entry(id)
	if e.is_empty():
		return ["The house has no such obligation."]
	active.erase(e)
	var q := def(id)
	var msg := "%s gives up %s. The notice goes back up in %s." % [d.heir.name, q.get("name", id), place_name(q.get("giver", ""))]
	d._say(msg)
	return [msg]


func turn_in(d: GameDynasty, id: String) -> Array:
	var e := entry(id)
	if e.is_empty():
		return ["The house has no such obligation."]
	var q := def(id)
	if not is_complete(e):
		return ["%s is not finished yet." % q["name"]]
	if d.world.location != q["giver"]:
		return ["%s is paid at the board in %s." % [q["name"], place_name(q["giver"])]]
	active.erase(e)
	record[id] = {"times": times_done(id) + 1, "gen": d.gen}
	if id not in done:
		done.append(id)
	var r: Dictionary = q.get("reward", {})
	var gold := reward_gold(d, q)
	var xp := reward_xp(d, q)
	d.heir.gold += gold
	var msgs: Array = ["Quest complete: %s. +%s gold, +%s XP." % [q["name"], GameText.num(gold), GameText.num(xp)]]
	if q.has("outcome"):
		msgs.append(str(q["outcome"]))
	if d.heir.gain_xp(xp) > 0:
		msgs.append("Level up! %s is now level %s." % [d.heir.name, GameText.num(d.heir.level)])
	for it in r.get("items", []):
		msgs.append(_reward_item(d, str(it)))
	var echo: Dictionary = r.get("echo", {})
	if not echo.is_empty():
		var text := str(echo.get("text", "{heir} answered the board")).format({"heir": d.heir.name})
		d._add_echo("glory", "quest_" + id, text, float(echo.get("strength", 0.05)))
		msgs.append("The tale spreads: %s." % text)
	for m in msgs:
		d._say(m)
	# Flags last, so any quest they complete reports after this one.
	for f in r.get("flags", []):
		d.set_flag(str(f))
	return msgs


## A reward the heir cannot carry (gear already owned, a full stack) is paid in gold, as events do:
## a notice taken again in a later Age must not fill the house's pack with copies.
static func _reward_item(d: GameDynasty, id: String) -> String:
	var h := d.heir
	var stack := GameItems.stack_max(id)
	var room: bool = GameItems.count(h, id) < stack if stack > 0 else not GameItems.owns(h, id)
	if room:
		return d.give_item(id)
	var g := maxi(1, int(round(float(GameItems.item_def(id).get("price", 0)) * GameData.enemy_scale(d.gen) * float(GameData.bal("event_duplicate_item_gold")))))
	h.gold += g
	return "%s already has the %s; the board pays %s gold for it instead." % [h.name, GameItems.item_name(id), GameText.num(g)]


## The hooks below journal at once, or append to `out` when the caller journals its own lines
## first (a travel or battle line must come before the quest it finished).
func _complete_note(d: GameDynasty, q: Dictionary, out: Variant) -> void:
	var line := "Quest done: %s. Report to the notice board in %s." % [q["name"], place_name(q["giver"])]
	if out is Array:
		out.append(line)
	else:
		d._say(line)


# ---------------------------------------------------------------- hooks from the dynasty

func on_kill(d: GameDynasty, creature_id: String, out: Variant = null) -> void:
	for e in active:
		var q := def(e["id"])
		if kind(q) != "kill" or creature_id not in targets(q) or is_complete(e):
			continue
		# An optional "place" means only kills made there count.
		if q["objective"].get("place", d.world.location) != d.world.location:
			continue
		e["progress"] = int(e["progress"]) + 1
		if is_complete(e):
			_complete_note(d, q, out)


func on_arrive(d: GameDynasty, place_id: String, out: Variant = null) -> void:
	for e in active:
		var q := def(e["id"])
		if kind(q) == "visit" and q["objective"].get("target", "") == place_id and not is_complete(e):
			e["progress"] = 1
			_complete_note(d, q, out)


func on_flag(d: GameDynasty, flag: String, out: Variant = null) -> void:
	for e in active:
		var q := def(e["id"])
		if kind(q) == "flag" and q["objective"].get("flag", "") == flag and not is_complete(e):
			e["progress"] = 1
			_complete_note(d, q, out)


## A new heir takes up the house's open quests. Hunts whose quarry has died out lapse.
func on_succession(d: GameDynasty, msgs: Array) -> void:
	for e in active.duplicate():
		var q := def(e["id"])
		if not is_complete(e) and not achievable(d, q):
			active.erase(e)
			msgs.append("The notice for %s has rotted on the board in %s: none of that quarry is left." % [q["name"], place_name(q["giver"])])
	if active.is_empty():
		return
	var names: Array = active.map(func(e): return "%s (%s)" % [def(e["id"])["name"], place_name(def(e["id"])["giver"])])
	msgs.append("%s inherits the house's obligations: %s." % [d.heir.name, ", ".join(names)])


# ---------------------------------------------------------------- autopilot

## Town errands the autopilot runs between actions (no time passes): turn in what is done,
## then take up notices this heir will finish without changing its habits.
static func bot_tick(d: GameDynasty) -> void:
	if d.state != "life" or d.battle != null or not d.world.has_service("board"):
		return
	var qs := d.quests
	var town := d.world.location
	for e in qs.active.duplicate():
		if qs.is_complete(e) and def(e["id"])["giver"] == town:
			qs.turn_in(d, e["id"])
	var trip := GameBot._legend_to_hunt(d)
	for q in qs.postings(d, town):
		if not _bot_can_do(d, q, trip):
			continue
		if qs.active.size() >= int(GameData.bal("quest_max_active")):
			# The bot rarely goes back to another town's board; make room for this one.
			# Unfinished notices go first; a finished one only if the bot can never claim it.
			var stale: Array = qs.active.filter(func(e): return def(e["id"])["giver"] != town and not qs.is_complete(e))
			if stale.is_empty():
				stale = qs.active.filter(func(e): return not (def(e["id"])["giver"] in [town, GameData.world["start"]]))
			if stale.is_empty():
				return
			qs.abandon(d, stale[0]["id"])
		if qs.accept_block(d, q["id"]) == "":
			qs.accept(d, q["id"])


## The bot hunts where it stands, travels only to legends' lairs, and never chases flags.
## It never walks back to claim a reward, so errands that take it out of town must come
## from the town every new heir starts in.
static func _bot_can_do(d: GameDynasty, q: Dictionary, trip: Dictionary) -> bool:
	var o: Dictionary = q["objective"]
	var home: bool = q["giver"] == GameData.world["start"]
	match kind(q):
		"kill":
			if o.get("place", d.world.location) != d.world.location:
				return false
			var biomes: Array = d.world.here().get("biomes", [])
			for t in targets(q):
				if not roams(d, t):
					continue
				var c := _creature(t)
				if c.get("boss", false):
					var lair: String = c.get("lair", "")
					if home and d.heir.level >= int(c.get("min_level", 1)) and (lair == d.world.location or not d.world.route_to(lair, d.flags).is_empty()):
						return true
				elif trip.is_empty() and (c.get("biomes", []) as Array).any(func(b): return b in biomes):
					return true
		"visit":
			return home and not trip.is_empty() and o.get("target", "") in d.world.route_to(trip["lair"], d.flags)
		"flag":
			return d.flags.has(o.get("flag", ""))
	return false


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	return {"active": active, "done": done, "record": record}


static func from_dict(v: Dictionary) -> GameQuests:
	var q := GameQuests.new()
	for e in v.get("active", []):
		var id := str(e.get("id", ""))
		if def(id).is_empty():
			continue
		q.active.append({"id": id, "progress": int(e.get("progress", 0)), "gen": int(e.get("gen", 1)), "by": str(e.get("by", ""))})
	for id in v.get("done", []):
		q.done.append(str(id))
	var rec: Dictionary = v.get("record", {})
	for id in rec:
		q.record[str(id)] = {"times": int(rec[id].get("times", 1)), "gen": int(rec[id].get("gen", 0))}
	for id in q.done:
		if not q.record.has(id):
			q.record[id] = {"times": 1, "gen": 0}
	return q
