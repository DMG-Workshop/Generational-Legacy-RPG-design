## Replay files: a run's seed, who founded it and the commands given, saved small and played back exactly.
## Everything random comes from the dynasty's seeded dice, so the same start and the same commands end the
## same way; a replay also carries a fingerprint of the dynasty every few commands and at the end, so playing
## it back proves it and, when a game version has changed what a command does, says where it first went
## different. Uses: a player's bug report (a line of text), the balance harness, a regression that cannot rot,
## and proof that a new view or renderer leaves the game alone. Logic only (no UI).
##
## A replay is {format, version, start, commands, checks, end}:
##   start: {seed, name, class, bloodline, race, sex, hard?}          how the dynasty was founded; `hard` (the house's
##          hard-mode options exactly as GameHardMode keeps them) is written only when a house was founded with one
##   commands: [{op, ...}]                                            see OPS
##   checks: [[index, fingerprint]]                                   after command `index` (0 based)
##   end: fingerprint after the last command
## As text it is "GLRP1:" + base64 of the gzipped JSON, one line to paste.
##
## Commands are checked against the game's own rules before they run (the right state, a known kind or stat,
## a stat that exists), so a damaged or hand-made replay is turned away with a reason, never run into a crash.
class_name GameReplay
extends RefCounted

const FORMAT := "GLRP1"
const PREFIX := "GLRP1:"
const MAX_BYTES := 8 * 1024 * 1024     # the most a replay may unpack to
const MAX_COMMANDS := 200000

## Every op, with the fields it takes. Life ops need the heir living and between fights with no event waiting;
## fight ops need a battle; the rest are named where they differ.
##   rest, work, explore, buy_potion, found_family {mate?}, retire    a life action
##   train {stat}, travel {to}, hunt {kind}, legend                   as the screens call them
##   resolve {choice}                                                 answer the waiting event
##   clock {seconds}                                                  the world clock is fed (GameClock)
##   turn                                                             one battle turn on the autopilot's tactics
##   act {act, kind?, id?, target?}                                   the heir's own battle command
##   finish                                                           settle a won, lost or fled fight
##   choose_heir {index}                                              pick the next heir
##   bot_step, bot_fight, choose_best                                 the autopilot's own decision, whole
const OPS := ["rest", "work", "explore", "buy_potion", "found_family", "retire", "train", "travel", "hunt", "legend",
	"resolve", "clock", "turn", "act", "finish", "choose_heir", "bot_step", "bot_fight", "choose_best"]
const ACTS := ["attack", "defend", "potion", "flee", "ability"]
const KINDS := ["skill", "spell", "feat", "vial"]

var start: Dictionary = {}
var commands: Array = []
var checks: Array = []
var check_every: int = 25
var dynasty: GameDynasty = null     # the dynasty being recorded (recording only)


# ---------------------------------------------------------------- recording

## Founds a dynasty and starts a replay of it. `check_every` sets how often a fingerprint is kept (1 finds
## a divergence to the exact command).
## `p_hard` founds the house with hard-mode options (GameHardMode.choices decides what they are). Options the game
## would refuse found a plain house, as GameDynasty.new_game does, and the replay then says nothing about them.
## The autopilot is given none by default, so its replays do not change.
static func begin(p_seed: int, founder_name: String, class_id: String, bloodline_id: String, race_id: String = "human",
		p_sex: String = GameSex.MALE, p_check_every: int = 25, p_hard: Dictionary = {}) -> GameReplay:
	var r := GameReplay.new()
	r.check_every = maxi(1, p_check_every)
	r.start = {"seed": p_seed, "name": founder_name, "class": class_id, "bloodline": bloodline_id, "race": race_id, "sex": p_sex}
	if not p_hard.is_empty():
		var c := GameHardMode.choices(p_hard)
		if c["ok"] and not (c["hard"] as Dictionary).is_empty():
			r.start["hard"] = (c["hard"] as Dictionary).duplicate(true)
	r.dynasty = found(r.start)
	return r


## Gives `cmd` to the dynasty and keeps it if it ran. Returns {ok, error}.
func do(cmd: Dictionary) -> Dictionary:
	var res := apply(dynasty, cmd)
	if res["ok"]:
		commands.append(cmd.duplicate(true))
		if commands.size() % check_every == 0:
			checks.append([commands.size() - 1, fingerprint(dynasty)])
	return res


## The autopilot lives on from here for up to `max_commands` commands, recording each decision, until the
## line ends or the heir dies with no successor to choose.
func bot_on(max_commands: int) -> void:
	var n := 0
	while n < max_commands and dynasty.state != "ended":
		n += 1
		var res: Dictionary
		if dynasty.state == "succession":
			res = do({"op": "choose_best"})
		elif dynasty.state == "life":
			if dynasty.battle != null:
				res = do({"op": "bot_fight"})
			elif dynasty.heir.age >= minf(dynasty.heir.lifespan, dynasty.heir.compute_lifespan(false)) * 0.9 and dynasty.can_retire():
				res = do({"op": "retire"})
			else:
				res = do({"op": "bot_step"})
		else:
			break
		if not res["ok"]:
			break


## The replay as a dictionary, with the end fingerprint taken now.
func to_dict() -> Dictionary:
	return {"format": FORMAT, "version": GameSaveVersion.CURRENT, "start": start.duplicate(true), "commands": commands.duplicate(true),
		"checks": checks.duplicate(true), "end": fingerprint(dynasty) if dynasty != null else ""}


func to_text() -> String:
	var json := JSON.stringify(to_dict())
	return PREFIX + Marshalls.raw_to_base64(json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


# ---------------------------------------------------------------- reading

## Reads a replay block. Returns {ok, error, replay}: `replay` is the checked dictionary. Spaces and line breaks
## are ignored. Anything not ours, damaged, from a newer game or the wrong shape is turned away with a reason.
static func from_text(text: String) -> Dictionary:
	var t := text
	for ws in [" ", "\n", "\r", "\t"]:
		t = t.replace(ws, "")
	if not t.begins_with(PREFIX):
		return _bad(GameMessages.text("life", "replay_not_replay"))
	var body := t.substr(PREFIX.length())
	var shape := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if body.length() % 4 != 0 or shape.search(body) == null:
		return _bad(GameMessages.text("life", "replay_unreadable"))
	var packed := Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return _bad(GameMessages.text("life", "replay_unreadable"))
	if packed.size() < 18 or packed[0] != 0x1f or packed[1] != 0x8b:   # checked first so the engine never logs a decode error
		return _bad(GameMessages.text("life", "replay_unreadable"))
	var raw := packed.decompress_dynamic(MAX_BYTES, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return _bad(GameMessages.text("life", "replay_incomplete"))
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return check(parsed)


## Checks the shape of a replay dictionary (what is there and of which kind), not whether it plays.
static func check(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return _bad(GameMessages.text("life", "replay_nothing"))
	var d: Dictionary = v
	if str(d.get("format", "")) != FORMAT:
		return _bad(GameMessages.text("life", "replay_wrong_kind"))
	var ver: Variant = d.get("version", null)
	if typeof(ver) != TYPE_INT and typeof(ver) != TYPE_FLOAT:
		return _bad(GameMessages.text("life", "replay_no_game"))
	if int(ver) > GameSaveVersion.CURRENT:
		return _bad(GameMessages.text("life", "replay_newer"))
	var s: Variant = d.get("start", null)
	if typeof(s) != TYPE_DICTIONARY:
		return _bad(GameMessages.text("life", "replay_no_start"))
	for k in ["seed", "name", "class", "bloodline", "race", "sex"]:
		if not s.has(k):
			return _bad(GameMessages.text("life", "replay_start_lacks", {"key": k}))
	if typeof(s["seed"]) != TYPE_INT and typeof(s["seed"]) != TYPE_FLOAT:
		return _bad(GameMessages.text("life", "replay_seed"))
	for k in ["name", "class", "bloodline", "race", "sex"]:
		if typeof(s[k]) != TYPE_STRING:
			return _bad(GameMessages.text("life", "replay_start_not_text", {"key": k}))
	if not GameData.classes.has(s["class"]) or not GameData.races.has(s["race"]) or not GameData.traits.has(s["bloodline"]):
		return _bad(GameMessages.text("life", "replay_unknown_start"))
	if s.has("hard"):
		var why := _hard_problem(s["hard"])
		if why != "":
			return _bad(why)
	var cmds: Variant = d.get("commands", null)
	if typeof(cmds) != TYPE_ARRAY or (cmds as Array).size() > MAX_COMMANDS:
		return _bad(GameMessages.text("life", "replay_commands"))
	for c in cmds:
		if typeof(c) != TYPE_DICTIONARY or typeof(c.get("op", null)) != TYPE_STRING:
			return _bad(GameMessages.text("life", "replay_bad_command"))
	var cks: Variant = d.get("checks", [])
	if typeof(cks) != TYPE_ARRAY:
		return _bad(GameMessages.text("life", "replay_checks"))
	for c in cks:
		if typeof(c) != TYPE_ARRAY or c.size() != 2 or typeof(c[0]) != TYPE_FLOAT and typeof(c[0]) != TYPE_INT or typeof(c[1]) != TYPE_STRING:
			return _bad(GameMessages.text("life", "replay_checks"))
	if typeof(d.get("end", "")) != TYPE_STRING:
		return _bad(GameMessages.text("life", "replay_end"))
	return {"ok": true, "error": "", "replay": d}


## Why a replay's founding hard-mode options cannot stand, or "" when they can. An entry must be exactly what
## GameHardMode keeps for a house (only the options that are on, a cap from its list), so a damaged or hand-made
## entry is refused with the reason rather than founding a house the game never could. An empty entry is no options.
static func _hard_problem(h: Variant) -> String:
	if typeof(h) != TYPE_DICTIONARY:
		return "The replay's hard-mode options are damaged: they are not a list of options."
	var c := GameHardMode.choices(h)
	if not c["ok"]:
		return "The replay's hard-mode options are not allowed: " + str(c["text"])
	var kept: Dictionary = c["hard"]
	if kept.size() != (h as Dictionary).size():
		return "The replay's hard-mode options are not written as a house keeps them: only options that are on are written."
	for k in kept:
		if h[k] != kept[k]:
			return "The replay's hard-mode options are not written as a house keeps them: '%s' is not as kept." % str(k)
	return ""


static func _bad(why: String) -> Dictionary:
	return {"ok": false, "error": why, "replay": {}}


# ---------------------------------------------------------------- playing

## Plays a checked replay from its start. Returns {ok, error, dynasty, played, diverged_at}: `ok` is true when
## every command ran and every fingerprint, the end one included, matched. `diverged_at` is the index of the
## first command after which a fingerprint differed (-1 if none); when checks are sparse the real divergence
## is at or before it, after the previous check. `error` says what went wrong.
static func play(rep: Dictionary, stop_at: int = -1) -> Dictionary:
	var out := {"ok": false, "error": "", "dynasty": null, "played": 0, "diverged_at": -1}
	var shape := check(rep)
	if not shape["ok"]:
		out["error"] = shape["error"]
		return out
	var d := found(rep["start"])
	if d == null:
		out["error"] = GameMessages.text("life", "replay_no_founding")
		return out
	out["dynasty"] = d
	var want: Dictionary = {}
	for c in rep.get("checks", []):
		want[int(c[0])] = str(c[1])
	var cmds: Array = rep["commands"]
	var last := cmds.size() if stop_at < 0 else mini(stop_at, cmds.size())
	for i in last:
		var res := apply(d, cmds[i])
		if not res["ok"]:
			out["error"] = "Command %d (%s) could not run: %s" % [i, str(cmds[i].get("op", "?")), res["error"]]
			out["played"] = i
			return out
		out["played"] = i + 1
		if want.has(i) and fingerprint(d) != want[i]:
			out["diverged_at"] = i
			out["error"] = GameMessages.text("life", "replay_went_differently", {"i": int(i), "op": str(cmds[i].get("op", "?"))})
			return out
	if stop_at < 0 and str(rep.get("end", "")) != "" and fingerprint(d) != str(rep["end"]):
		out["diverged_at"] = cmds.size() - 1
		out["error"] = GameMessages.text("life", "replay_ended_differently")
		return out
	out["ok"] = true
	return out


# ---------------------------------------------------------------- the commands

static func found(s: Dictionary) -> GameDynasty:
	var hard: Dictionary = s["hard"] if typeof(s.get("hard")) == TYPE_DICTIONARY else {}
	return GameDynasty.new_game(int(s["seed"]), str(s["name"]), str(s["class"]), str(s["bloodline"]), str(s["race"]), str(s["sex"]), "", hard)


## A short fingerprint of everything a run has made so far: the dynasty as it would be saved (a fight in
## progress included) and the state of its dice.
static func fingerprint(d: GameDynasty) -> String:
	return (JSON.stringify(d.to_save(), "", true) + "|" + str(d.rng.state)).sha256_text().substr(0, 16)


static func _no(why: String) -> Dictionary:
	return {"ok": false, "error": why}


## Runs one command on `d` after checking the game allows it. Returns {ok, error}; nothing runs on a refusal.
static func apply(d: GameDynasty, cmd: Dictionary) -> Dictionary:
	var op := str(cmd.get("op", ""))
	if op not in OPS:
		return _no(GameMessages.text("life", "replay_not_a_command", {"op": op}))
	var fight := d.battle != null
	var living := d.state == "life"
	match op:
		"choose_heir", "choose_best":
			if d.state != "succession":
				return _no(GameMessages.text("life", "no_heir_now"))
			if op == "choose_heir":
				if not _int(cmd.get("index")) or int(cmd["index"]) < 0 or int(cmd["index"]) >= d.candidates.size():
					return _no(GameMessages.text("life", "not_candidate"))
				d.choose_heir(int(cmd["index"]))
			else:
				GameBot.choose_best(d)
			return {"ok": true, "error": ""}
		"turn", "act", "finish", "bot_fight":
			if not living or not fight:
				return _no(GameMessages.text("life", "no_fight"))
			if op == "finish":
				if not d.battle.is_over():
					return _no(GameMessages.text("life", "fight_not_over"))
				d.finish_battle()
			elif op == "bot_fight":
				GameBot.fight(d)
			else:
				if d.battle.is_over():
					return _no(GameMessages.text("life", "fight_is_over"))
				if op == "turn":
					GameTactics.auto_turn(d.battle)
				else:
					var why := _act(d.battle, cmd)
					if why != "":
						return _no(why)
			return {"ok": true, "error": ""}
	# life ops
	if not living or fight:
		return _no(GameMessages.text("life", "cannot_now"))
	if op == "resolve":
		if not d.has_pending_event():
			return _no(GameMessages.text("life", "no_event"))
		if not _int(cmd.get("choice")) or int(cmd["choice"]) < 0:
			return _no(GameMessages.text("life", "not_a_choice"))
		d.resolve_event(int(cmd["choice"]))
		return {"ok": true, "error": ""}
	if op == "bot_step":
		GameBot.step(d)
		return {"ok": true, "error": ""}
	if d.has_pending_event():
		return _no(GameMessages.text("life", "event_waiting"))
	match op:
		"rest":
			d.rest()
		"work":
			d.work()
		"explore":
			d.explore()
		"buy_potion":
			d.buy_potion()
		"retire":
			if not d.can_retire():
				return _no(GameMessages.text("life", "too_soon_retire_replay"))
			d.retire()
		"found_family":
			if not d.can_found_family():
				return _no(GameMessages.text("life", "cannot_found_yet"))
			d.found_family(int(cmd["mate"]) if _int(cmd.get("mate")) else -1)
		"train":
			if typeof(cmd.get("stat")) != TYPE_STRING or not d.heir.training.has(cmd["stat"]):
				return _no(GameMessages.text("life", "not_a_stat"))
			d.train(cmd["stat"])
		"travel":
			if typeof(cmd.get("to")) != TYPE_STRING or str(cmd["to"]) == "":
				return _no(GameMessages.text("life", "nowhere_travel"))
			d.travel(cmd["to"])
		"hunt":
			if typeof(cmd.get("kind")) != TYPE_STRING or not GameData.bal("hunt_rewards").has(cmd["kind"]):
				return _no(GameMessages.text("life", "not_a_hunt"))
			d.start_hunt(cmd["kind"])
		"legend":
			if d.start_legend() == null:
				return _no(GameMessages.text("life", "no_legend"))
		"clock":
			if (typeof(cmd.get("seconds")) != TYPE_FLOAT and typeof(cmd.get("seconds")) != TYPE_INT) or not is_finite(float(cmd["seconds"])) or float(cmd["seconds"]) <= 0.0:
				return _no(GameMessages.text("life", "not_a_time"))
			GameClock.feed(d, float(cmd["seconds"]))
	return {"ok": true, "error": ""}


static func _int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v))


## The heir's own battle command, through the battle's public methods as the screens call them. "" when it ran,
## else why it could not.
static func _act(b: GameBattle, cmd: Dictionary) -> String:
	var act := str(cmd.get("act", ""))
	if act not in ACTS:
		return GameMessages.text("life", "replay_not_battle_action", {"act": act})
	var target := -1
	var ref := str(cmd.get("target", ""))
	if ref.begins_with("enemy:"):
		target = int(ref.get_slice(":", 1))
		if target < 0 or target >= b.enemies.size():
			return GameMessages.text("life", "no_such_foe")
	match act:
		"attack":
			b.attack(target)
		"defend":
			b.defend()
		"potion":
			b.use_potion()
		"flee":
			b.flee()
		"ability":
			var kind := str(cmd.get("kind", ""))
			var id := str(cmd.get("id", ""))
			if kind not in KINDS:
				return GameMessages.text("life", "replay_not_ability", {"kind": kind})
			match kind:
				"skill":
					var skills: Array = GameSkillTree.skills(b.heir)
					for i in skills.size():
						if str(skills[i]["id"]) == id:
							b.use_skill(i, target)
							return ""
					return GameMessages.text("life", "replay_no_skill", {"id": id})
				"spell":
					if id not in b.heir.spells:
						return GameMessages.text("life", "replay_no_spell", {"id": id})
					b.cast_spell(id, target)
				"feat":
					var at := b.heir.equipped_feats.find(id)
					if at < 0:
						return GameMessages.text("life", "replay_feat_not_equipped", {"id": id})
					b.use_feat(at, target)
				"vial":
					if id not in b.heir.inventory:
						return GameMessages.text("life", "replay_no_vial", {"id": id})
					b.throw_vial(id, target)
	return ""
