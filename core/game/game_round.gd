## Party command rounds: in manual mode the player decides for every member of the party in turn
## (the heir, then each companion, from that member's own skills, spells, feats and the shared
## items), the choices queue, and the whole round then plays out together in the battle's fixed
## initiative: heir, companions by party index, foes by index. Choosing is free and undoable; the
## queue is plain data (no dice, no change to the battle). resolve() is the one place the battle
## moves, and it runs the same per-action code paths the heir's own buttons always did. Members set
## to Auto are decided at their own turn by GameTactics, exactly as companions always were. No node,
## no UI, no RNG of its own. Autopilots (GameBot, auto-battle) never use this class.
##
## ============================ PUBLIC INTERFACE (frozen; additions only) ============================
##
## A member is `by`: -1 the heir, else the companion's index in `battle.allies`.
##
## COMMAND (a queued decision; plain Dictionary, JSON-able, targets are refs never raw indices):
##   {"act": "attack"|"defend"|"potion"|"flee"|"ability",
##    "kind": "skill"|"spell"|"feat"|"vial",     # act == "ability" only
##    "id": String,                              # class skill "id", spell id, feat id, vial item id
##    "target": String}                          # "" | "enemy:2" | "ally:1" | "heir"
##   Foe aims (aim "foe"/"area") need an "enemy:N" target. Aim "ally" (a single heal) takes "heir",
##   "ally:N" or "" (the most hurt member at that member's turn). Aim "none" takes "".
##
## ENTRY (this round's decision for one member, `entries[by]`): {"cmd": Dictionary, "src": String}
##   src "manual" (picked), "repeat" (re-queued by repeat_last), "cover" (the party flees: this member
##   passes), "held" (cannot act: stunned, asleep, frozen; never asked), "auto_once" (repeat_last
##   could not re-queue it: acts as Auto this round only; `cmd` is {}). No entry plus auto[by] means
##   Auto, decided at the member's own turn.
##
## STATIC
##   static func setting(key: String) -> Variant        # data/combat/rounds.json "settings"
##   static func validate() -> Array                    # data problems, one readable line each; [] if sound
##   static func open(b: GameBattle, prefs: Dictionary = {}, party: GameParty = null) -> GameRound
##       # reads the Auto switches (prefs = GameDynasty.auto_party, party = GameDynasty.party), begin_round()
##   static func plan_for(b: GameBattle, by: int, cmd: Dictionary) -> Dictionary
##       # cmd -> the plan GameTactics/GameBattle run, retargeted for the battle as it stands now; {} if illegal now
##   static func retarget_foe(b: GameBattle, ref: String) -> int   # the living foe nearest the (fallen) one, lowest index on ties; -1 none
##   static func retarget_ally(b: GameBattle) -> int               # the most hurt conscious party member (-1 heir, else ally index)
##
## STATE (read-only for the UI)
##   var b: GameBattle
##   var auto: Dictionary       # by -> bool, the Auto switches (heir -1 included)
##   var entries: Dictionary    # by -> ENTRY, this round's decisions
##   var last: Dictionary       # by -> COMMAND of the last resolved round (only members who chose by hand)
##   var cursor: int            # member being asked (-2 none)
##   var flee_by: int           # member whose Flee covers the party (-2 none)
##   var number: int            # battle turn the round opened on
##
## ROUND
##   func begin_round() -> void          # fresh round: clears entries and flee, Held members filled, cursor set
##   func members() -> Array             # [-1, 0, 2]: the heir and the conscious companions, in initiative order
##   func state_of(by: int) -> String    # "ready" | "held" | "ko"
##   func needs_input(by: int) -> bool   # ready, not Auto, no entry yet
##   func manual_count() -> int          # members who take input this round (ready and not Auto)
##   func next_unset() -> int            # first member (in order) that needs_input, else -2
##   func ready() -> bool                # every member is Auto, Held, covered or has an entry
##   func auto_commits() -> bool         # manual_count() <= 1 and not settings.confirm_single: the UI resolves right after queue()
##
## CHOOSING
##   func menu(by: int) -> Array         # rows, see ROW below, in display order; [] for a fallen member
##   func aim_of(cmd: Dictionary, by: int = -2) -> String   # "foe" | "area" | "ally" | "none" (by -2: the cursor member, else the heir)
##   func check(by: int, cmd: Dictionary) -> String         # "" if it can be queued now, else the reason (player-readable)
##   func queue(by: int, cmd: Dictionary) -> String         # "" ok (replaces by's earlier decision, advances cursor); else the reason, nothing changed
##   func unqueue(by: int) -> void       # drop by's decision (cursor returns to by)
##   func back() -> int                  # undo the most recently queued member; returns the member to ask (or the cursor)
##   func clear() -> void                # drop every decision made by hand (Held stay)
##   func focus(by: int) -> bool         # jump the cursor to a member who is not Held or fallen
##   func set_auto(by: int, on: bool) -> void   # the Auto switch; drops by's decision; remembered (prefs / party record)
##   func repeat_last() -> Dictionary    # {"repeated": [by..], "fallback": [by..]}: re-queues last round's choices
##   func can_repeat() -> bool           # last round had hand-made choices and nothing is queued yet
##   func coat(item: String) -> void     # the heir's free toxin coat: immediate, not undoable (events left in battle.events)
##   func view() -> Dictionary           # the read model, see VIEW below
##   func describe(by: int, cmd: Dictionary) -> Dictionary   # {"full", "short", "tiny"} chip texts, no pixels
##   func resolve() -> Dictionary        # plays the round: {"log_from": int, "over": bool, "result": String, "played": bool}
##       # played is false (nothing happened) when not ready() or the fight is over. A new round opens
##       # by itself afterwards unless the fight ended.
##
## ROW (menu(by) entry):
##   {"cmd": Dictionary (target "" for foe/ally aims: the UI fills it), "group": "basic"|"skill"|"spell"|"feat"|"item",
##    "label": String, "cost": String ("6 MP" | "14 HP" | "1 left" | ""), "enabled": bool, "why": String ("" when enabled),
##    "aim": "foe"|"area"|"ally"|"none", "ab": Dictionary (the ability, {} for basic rows), "first": bool (a class skill open
##    from level 1: gets its own button; false: in the Skills list), "level": int (skill opening level, else 0), "tip": String}
##
## VIEW (view()):
##   {"number": int, "cursor": int, "ready": bool, "can_back": bool, "can_repeat": bool, "flee": bool (a Flee is queued),
##    "auto_commit": bool, "manual_count": int, "over": bool,
##    "members": [{"by": int, "ref": "heir"|"ally:N", "name": String, "hp": int, "max_hp": int, "mp": int, "max_mp": int,
##       "state": "ready"|"held"|"ko", "auto": bool,
##       "decision": "queued"|"empty"|"auto"|"held"|"cover"|"fallback"|"ko",
##       "chip": {"full", "short", "tiny"}, "kind": "attack"|"skill"|"spell"|"feat"|"item"|"defend"|"flee"|"auto"|"held"|"ko"|"empty",
##       "statuses": [String], "tip": String}]}      # every companion of the battle, fallen ones included, in index order
##
## EVENTS (in battle.events during resolve(); everything else is the existing vocabulary):
##   {"type": "round", "n": int}                                       first
##   {"type": "act", "by": -1|ai, "manual": bool [, "fallback": true] [, "flee": true] [, "held": true]}   before each member's action
##                                                                     (a fallback marker follows the first one of the same member)
##   {"type": "foes"}                                                  before the first foe acts
##   a companion's Defend is {"type": "defend", "by": ai}; the heir's old {"type": "defend"} has no "by" (read it as -1).
## ====================================================================================================
class_name GameRound
extends RefCounted

var b: GameBattle
var auto: Dictionary = {}
var entries: Dictionary = {}
var last: Dictionary = {}
var cursor: int = -2
var flee_by: int = -2
var number: int = 0
var _order: Array = []       # members in the order they were queued, for Back
var _stash: Dictionary = {}  # entries a queued Flee covered, to give back if it is taken back
var _prefs: Dictionary = {}  # GameDynasty.auto_party (shared reference)
var _party: GameParty = null


# ---------------------------------------------------------------- data

static func setting(key: String) -> Variant:
	GameData.load_all()
	return GameData.combat["rounds"]["settings"][key]


## Everything wrong with data/combat/rounds.json, one readable line each; empty when it is sound.
static func validate() -> Array:
	GameData.load_all()
	var out: Array = []
	var s: Dictionary = GameData.combat.get("rounds", {}).get("settings", {})
	for key in ["party_order", "default_auto", "flee_covers_party", "confirm_single", "ally_defend", "defend_mp_pct", "brace_taken", "potion_for_companions", "chip_texts"]:
		if not s.has(key):
			out.append("rounds: settings has no %s" % key)
	if not out.is_empty():
		return out
	if str(s["party_order"]) not in ["fixed"]:
		out.append("rounds: party_order must be \"fixed\"")
	var da = s["default_auto"]
	if typeof(da) != TYPE_DICTIONARY or typeof(da.get("heir")) != TYPE_BOOL or typeof(da.get("companion")) != TYPE_BOOL:
		out.append("rounds: default_auto needs boolean heir and companion")
	for key in ["flee_covers_party", "confirm_single", "ally_defend", "potion_for_companions"]:
		if typeof(s[key]) != TYPE_BOOL:
			out.append("rounds: %s must be true or false" % key)
	if typeof(s["defend_mp_pct"]) not in [TYPE_FLOAT, TYPE_INT] or float(s["defend_mp_pct"]) < 0.0 or float(s["defend_mp_pct"]) > 1.0:
		out.append("rounds: defend_mp_pct must be a fraction from 0 to 1")
	if typeof(s["brace_taken"]) not in [TYPE_FLOAT, TYPE_INT] or float(s["brace_taken"]) <= 0.0 or float(s["brace_taken"]) > 1.0:
		out.append("rounds: brace_taken must be above 0 and at most 1")
	var ct = s["chip_texts"]
	if typeof(ct) != TYPE_DICTIONARY:
		out.append("rounds: chip_texts must be an object")
	else:
		var sh := int(ct.get("short_chars", 0))
		var ti := int(ct.get("tiny_chars", 0))
		if ti < 2 or sh < ti:
			out.append("rounds: chip_texts needs 2 <= tiny_chars <= short_chars")
		var ab = ct.get("abbrev", {})
		if typeof(ab) != TYPE_DICTIONARY:
			out.append("rounds: chip_texts.abbrev must be an object")
		else:
			for k in ab:
				if str(ab[k]).length() > maxi(ti, 2) + 2:
					out.append("rounds: abbrev %s is longer than a tiny chip" % k)
	return out


# ---------------------------------------------------------------- opening a round

## The round for a battle that has just begun. `prefs` is GameDynasty.auto_party and `party` the
## dynasty's GameParty: the Auto switches are read from them and written back to them.
static func open(p_b: GameBattle, prefs: Dictionary = {}, party: GameParty = null) -> GameRound:
	var r := GameRound.new()
	r.b = p_b
	r._prefs = prefs
	r._party = party
	r.auto[-1] = r._stored_auto(-1)
	for ai in p_b.allies.size():
		r.auto[ai] = r._stored_auto(ai)
	r.begin_round()
	return r


func _member_of(by: int) -> Dictionary:
	if by < 0 or _party == null or by >= b.allies.size():
		return {}
	return _party.member(str(b.allies[by].get_meta("companion", "")))


func _stored_auto(by: int) -> bool:
	var defaults: Dictionary = setting("default_auto")
	if by < 0:
		return bool(_prefs.get("heir", defaults["heir"]))
	var m := _member_of(by)
	if m.has("auto"):
		return bool(m["auto"])
	return bool(_prefs.get("companion_default", defaults["companion"]))


func begin_round() -> void:
	entries = {}
	flee_by = -2
	_stash = {}
	_order = []
	number = b.turn
	for by in members():
		if state_of(by) == "held":
			entries[by] = {"cmd": {}, "src": "held"}
	cursor = next_unset()


func members() -> Array:
	var out: Array = []
	if b.heir.hp > 0:
		out.append(-1)
	out.append_array(b.conscious_allies())
	return out


func state_of(by: int) -> String:
	if by < -1 or by >= b.allies.size() or b.unit(by).hp <= 0:
		return "ko"
	if by < 0:
		return "held" if b.heir_skip else "ready"
	return "held" if b.is_held(GameBattle.ref_of(by)) else "ready"


func needs_input(by: int) -> bool:
	return state_of(by) == "ready" and not bool(auto.get(by, false)) and not entries.has(by)


func manual_count() -> int:
	var n := 0
	for by in members():
		if state_of(by) == "ready" and not bool(auto.get(by, false)):
			n += 1
	return n


func next_unset() -> int:
	for by in members():
		if needs_input(by):
			return by
	return -2


func ready() -> bool:
	return not b.is_over() and not members().is_empty() and next_unset() == -2


func auto_commits() -> bool:
	return manual_count() <= 1 and not bool(setting("confirm_single"))


# ---------------------------------------------------------------- what can be chosen

static func _aim(ab: Dictionary) -> String:
	if GameCombat.aims_at_foe(ab):
		if GameCombat.around_self(ab) or GameCombat.shape(ab) == "all":
			return "none"
		return "area" if GameCombat.is_aoe(ab) else "foe"
	if ab.has("pct_max_hp") and not ab.get("party", false):
		return "ally"
	return "none"


func aim_of(cmd: Dictionary, by: int = -2) -> String:
	if str(cmd.get("act", "")) == "attack":
		return "foe"
	if str(cmd.get("act", "")) != "ability":
		return "none"
	var who := by if by != -2 else (cursor if cursor != -2 else -1)
	return _aim(_ability_of(b, who, cmd).get("ab", {}))


## The ability a command names for a member, with what it costs and why it cannot be used now:
## {ab, cost, skill, spell, feat, item, why}. `why` "" when the member can use it (aim aside).
static func _ability_of(p_b: GameBattle, by: int, cmd: Dictionary) -> Dictionary:
	if by < -1 or by >= p_b.allies.size():
		return {"why": "Out of the fight."}
	var u := p_b.unit(by)
	var id := str(cmd.get("id", ""))
	match str(cmd.get("kind", "")):
		"skill":
			var skills: Array = GameSkillTree.skills(u)
			for i in skills.size():
				if str(skills[i].get("id", "")) != id:
					continue
				var cost := GameBattle.unit_skill_cost(u, i)
				var why := ""
				if not GameSkills.unlocked(u, i):
					why = "Opens at level %d." % GameSkills.level_of(skills[i])
				elif p_b.unit_skill_used_up(by, i):
					why = "Used this battle."
				elif not p_b.can_pay(by, cost):
					why = _short_of(p_b, by)
				return {"ab": skills[i], "cost": cost, "skill": i, "spell": "", "feat": "", "item": "", "why": why}
			return {"why": "No such skill."}
		"spell":
			if id not in p_b.unit_spells(by):
				return {"why": "Not known."}
			var sp := p_b.unit_spell(by, id)
			if sp.is_empty():
				return {"why": "Not known."}
			var cost := GameCombat.ability_cost(sp, u.level)
			return {"ab": sp, "cost": cost, "skill": -1, "spell": id, "feat": "", "item": "",
				"why": "" if p_b.can_pay(by, cost) else _short_of(p_b, by)}
		"feat":
			if id not in p_b.unit_feats(by):
				return {"why": "Not readied."}
			return {"ab": p_b.unit_feat(by, id), "cost": 0, "skill": -1, "spell": "", "feat": id, "item": "", "why": p_b.feat_block(by, id)}
		"vial":
			if by >= 0:
				return {"why": "Only the heir throws vials."}
			if id not in p_b.heir.inventory or GameItems.kind_of(id) != "vial":
				return {"why": "No such vial."}
			return {"ab": GamePlague.vial_ability(id), "cost": 0, "skill": -1, "spell": "", "feat": "", "item": id, "why": ""}
	return {"why": "Unknown command."}


static func _short_of(p_b: GameBattle, by: int) -> String:
	return "Too hurt." if p_b.pays_in_hp(by) else "Not enough MP."


static func _foe_index(ref: String) -> int:
	return int(ref.get_slice(":", 1)) if ref.begins_with("enemy:") else -1


static func _why_foe(p_b: GameBattle, ref: String) -> String:
	var i := _foe_index(ref)
	if i < 0 or i >= p_b.enemies.size():
		return "Choose a foe."
	return "" if p_b.enemies[i]["hp"] > 0 else "That foe has fallen."


## Party member a ref names: -1 the heir, an ally index, or -2 when it names none.
static func _party_index(ref: String) -> int:
	if ref == "heir":
		return -1
	if ref.begins_with("ally:"):
		return int(ref.get_slice(":", 1))
	return -2


## Whether `cmd` could be used by `by` right now, ignoring who else has queued what. `held` is the
## stock other members have already reserved: {"potions": n, "vials": {item: n}}.
static func _why_not(p_b: GameBattle, by: int, cmd: Dictionary, held: Dictionary = {}) -> String:
	var target := str(cmd.get("target", ""))
	match str(cmd.get("act", "")):
		"attack":
			return "" if target == "" else _why_foe(p_b, target)
		"defend":
			return "" if by < 0 or bool(setting("ally_defend")) else "Companions do not defend."
		"potion":
			if by >= 0 and not bool(setting("potion_for_companions")):
				return "Companions do not drink the house's potions."
			return "" if p_b.heir.potions - int(held.get("potions", 0)) > 0 else "No potions left."
		"flee":
			return "Held fast." if p_b.heir_skip else ""
		"pass":
			return ""
		"ability":
			var info := _ability_of(p_b, by, cmd)
			if str(info["why"]) != "":
				return str(info["why"])
			if str(info["item"]) != "":
				var carried := (p_b.heir.inventory as Array).count(info["item"])
				if carried - int((held.get("vials", {}) as Dictionary).get(info["item"], 0)) <= 0:
					return "No more of those."
			var ab: Dictionary = info["ab"]
			match _aim(ab):
				"foe", "area":
					var w := _why_foe(p_b, target)
					if w != "":
						return w
					if p_b.aoe_hits(ab, by, _foe_index(target)).is_empty():
						return "Out of reach."
				"ally":
					if target != "":
						var who := _party_index(target)
						if who < -1 or who >= p_b.allies.size() or p_b.unit(who).hp <= 0:
							return "Out of the fight."
				_:
					if GameCombat.aims_at_foe(ab) and p_b.aoe_hits(ab, by, p_b.first_target()).is_empty():
						return "Out of reach."
			return ""
	return "Unknown command."


## Potions and vials the other members have queued, so the stock is not promised twice.
func _reserved(except: int) -> Dictionary:
	var held := {"potions": 0, "vials": {}}
	for by in entries:
		if by == except or str(entries[by]["src"]) not in ["manual", "repeat"]:
			continue
		var cmd: Dictionary = entries[by]["cmd"]
		if str(cmd.get("act", "")) == "potion":
			held["potions"] = int(held["potions"]) + 1
		elif str(cmd.get("kind", "")) == "vial":
			held["vials"][cmd["id"]] = int(held["vials"].get(cmd["id"], 0)) + 1
	return held


func check(by: int, cmd: Dictionary) -> String:
	if b.is_over():
		return "The fight is over."
	if by not in members():
		return "Out of the fight."
	if state_of(by) == "held":
		return "Held fast."
	return _why_not(b, by, cmd, _reserved(by))


func queue(by: int, cmd: Dictionary) -> String:
	var why := check(by, cmd)
	if why != "":
		return why
	if flee_by != -2:   # any new decision takes a queued Flee back
		var fleeing := flee_by
		_unflee()
		_drop_entry(fleeing)
	_drop_entry(by)
	entries[by] = {"cmd": cmd.duplicate(true), "src": "manual"}
	_order.append(by)
	if str(cmd.get("act", "")) == "flee":
		flee_by = by
		_stash = {}
		for other in members():
			if other == by or str(entries.get(other, {}).get("src", "")) == "held":
				continue
			if entries.has(other):
				_stash[other] = entries[other]
			entries[other] = {"cmd": {}, "src": "cover"}
	cursor = next_unset()
	return ""


func _drop_entry(by: int) -> void:
	if entries.has(by) and str(entries[by]["src"]) != "held":
		entries.erase(by)
	_order.erase(by)


## Takes a queued Flee back: everyone it covered gets their own decision back.
func _unflee() -> void:
	if flee_by == -2:
		return
	for other in entries.keys():
		if str(entries[other]["src"]) == "cover":
			entries.erase(other)
	for other in _stash:
		entries[other] = _stash[other]
	_stash = {}
	flee_by = -2


func unqueue(by: int) -> void:
	if flee_by == by:
		_unflee()
	_drop_entry(by)
	cursor = by if needs_input(by) else next_unset()


func back() -> int:
	if _order.is_empty():
		return cursor
	var by: int = _order.back()
	unqueue(by)
	cursor = by
	return by


func clear() -> void:
	_unflee()
	for by in entries.keys():
		if str(entries[by]["src"]) != "held":
			entries.erase(by)
	_order = []
	cursor = next_unset()


func focus(by: int) -> bool:
	if by not in members() or state_of(by) != "ready":
		return false
	cursor = by
	return true


func set_auto(by: int, on: bool) -> void:
	if by not in auto:
		return
	auto[by] = on
	unqueue(by)
	if by < 0:
		_prefs["heir"] = on
	else:
		var m := _member_of(by)
		if not m.is_empty():
			m["auto"] = on
	cursor = by if not on and needs_input(by) else next_unset()


func can_repeat() -> bool:
	if last.is_empty() or not _order.is_empty() or flee_by != -2 or b.is_over():
		return false
	for by in last:
		if by in members() and state_of(by) == "ready" and not bool(auto.get(by, false)):
			return true
	return false


## Re-queues what each member chose by hand last round; a choice that is no longer possible (a
## fallen target is moved to the nearest foe first) becomes Auto for this round only.
func repeat_last() -> Dictionary:
	var out := {"repeated": [], "fallback": []}
	if not can_repeat():
		return out
	for by in members():
		if state_of(by) != "ready" or not last.has(by) or bool(auto.get(by, false)):
			continue
		var cmd := _retargeted(b, by, last[by])
		if check(by, cmd) == "":
			entries[by] = {"cmd": cmd, "src": "repeat"}
			(out["repeated"] as Array).append(by)
		else:
			entries[by] = {"cmd": {}, "src": "auto_once"}
			(out["fallback"] as Array).append(by)
		_order.append(by)
	cursor = next_unset()
	return out


func coat(item: String) -> void:
	b.coat_blade(item)


# ---------------------------------------------------------------- retargeting

static func retarget_foe(p_b: GameBattle, ref: String) -> int:
	var living := p_b.living_enemies()
	if living.is_empty():
		return -1
	var i := _foe_index(ref)
	if i < 0 or i >= p_b.enemies.size():
		return p_b._valid_target(p_b.focus)
	if p_b.enemies[i]["hp"] > 0:
		return i
	var from := p_b.enemy_point(i)
	var best: int = living[0]
	var best_d := from.distance_to(p_b.enemy_point(best))
	for j in living:
		var d := from.distance_to(p_b.enemy_point(j))
		if d < best_d - 0.0001:
			best = j
			best_d = d
	return best


static func retarget_ally(p_b: GameBattle) -> int:
	var best := -1
	var best_f := 2.0
	for who in [-1] + p_b.conscious_allies():
		var f := float(p_b.unit(who).hp) / float(maxi(1, int(p_b.unit_numbers(who)["max_hp"])))
		if f < best_f - 0.000001:
			best = who
			best_f = f
	return best


## A copy of `cmd` whose target is still standing: a fallen foe gives way to the nearest living one,
## a healing target who fell to the most hurt member.
static func _retargeted(p_b: GameBattle, by: int, cmd: Dictionary) -> Dictionary:
	var out := cmd.duplicate(true)
	var target := str(out.get("target", ""))
	var aim := "foe" if str(out.get("act", "")) == "attack" else "none"
	if str(out.get("act", "")) == "ability":
		aim = _aim(_ability_of(p_b, by, out).get("ab", {}))
	match aim:
		"foe", "area":
			if _foe_index(target) >= 0 and _why_foe(p_b, target) != "":
				var t := retarget_foe(p_b, target)
				out["target"] = "enemy:%d" % t if t >= 0 else ""
		"ally":
			var who := _party_index(target)
			if target != "" and (who < -1 or who >= p_b.allies.size() or p_b.unit(who).hp <= 0):
				out["target"] = GameBattle.ref_of(retarget_ally(p_b))
	return out


# ---------------------------------------------------------------- command -> plan

## The plan (see GameTactics.choose) for a member's command at its turn, or {} when it cannot be
## carried out any more: the command is checked again here with the same rules as at queue time,
## after a fallen target has been replaced.
static func plan_for(p_b: GameBattle, by: int, cmd: Dictionary) -> Dictionary:
	if p_b.is_over() or cmd.is_empty() or by < -1 or by >= p_b.allies.size():
		return {}
	var c := _retargeted(p_b, by, cmd)
	var act := str(c.get("act", ""))
	var target := str(c.get("target", ""))
	if act == "attack":
		var t := _foe_index(target) if target != "" else p_b._valid_target(p_b.focus)
		return {"act": "attack", "target": t} if t >= 0 and p_b.enemies[t]["hp"] > 0 else {}
	if _why_not(p_b, by, c) != "":
		return {}
	match act:
		"defend", "potion", "pass":
			var plan := {"act": act}
			if c.has("text"):
				plan["text"] = c["text"]
			return plan
		"ability":
			var info := _ability_of(p_b, by, c)
			var ab: Dictionary = info["ab"]
			var t := -1
			match _aim(ab):
				"foe", "area":
					t = _foe_index(target)
				"ally":
					t = _party_index(target) if target != "" else retarget_ally(p_b)
				_:
					t = p_b.first_target() if GameCombat.aims_at_foe(ab) else -1
			return {"act": "ability", "ab": ab, "cost": info["cost"], "mp": info["cost"], "skill": info["skill"], "spell": info["spell"],
				"feat": info["feat"], "item": info["item"], "target": t}
	return {}


# ---------------------------------------------------------------- menus

func _row(by: int, group: String, cmd: Dictionary, label: String, cost: String, ab: Dictionary, why: String) -> Dictionary:
	var aim := "foe" if str(cmd.get("act", "")) == "attack" else (_aim(ab) if not ab.is_empty() else "none")
	var enabled := why == ""
	return {"cmd": cmd, "group": group, "label": label, "cost": cost, "enabled": enabled, "why": why, "aim": aim, "ab": ab,
		"first": false, "level": 0, "tip": "" if ab.is_empty() else "%s. %s" % [GameCombat.shape_text(ab), GameCombat.describe(ab)]}


## Why a row cannot be used: for foe aims the best answer over every living foe.
func _row_why(by: int, cmd: Dictionary, ab: Dictionary) -> String:
	var aim := "foe" if str(cmd.get("act", "")) == "attack" else (_aim(ab) if not ab.is_empty() else "none")
	if aim not in ["foe", "area"]:
		return check(by, cmd)
	var first := ""
	for i in b.living_enemies():
		var c := cmd.duplicate()
		c["target"] = "enemy:%d" % i
		var why := check(by, c)
		if why == "":
			return ""
		if first == "":
			first = why
	return first if first != "" else "No foes."


func menu(by: int) -> Array:
	var rows: Array = []
	if by not in members():
		return rows
	var u := b.unit(by)
	var attack := {"act": "attack", "target": ""}
	rows.append(_row(by, "basic", attack, "Attack", "", {}, _row_why(by, attack, {})))
	var defend := {"act": "defend"}
	rows.append(_row(by, "basic", defend, "Defend", "", {}, check(by, defend)))
	var potion := {"act": "potion"}
	var left := b.heir.potions - int(_reserved(by)["potions"])
	var prow := _row(by, "basic", potion, "Potion", "%d left" % maxi(0, left), {}, check(by, potion))
	rows.append(prow)
	var flee := {"act": "flee"}
	rows.append(_row(by, "basic", flee, "Flee", "", {}, check(by, flee)))
	var skills: Array = GameSkillTree.skills(u)
	for i in skills.size():
		var cmd := {"act": "ability", "kind": "skill", "id": str(skills[i]["id"]), "target": ""}
		var row := _row(by, "skill", cmd, str(skills[i].get("name", "?")), b.pay_text(by, GameBattle.unit_skill_cost(u, i)), skills[i], _row_why(by, cmd, skills[i]))
		row["level"] = GameSkills.level_of(skills[i])
		row["first"] = int(row["level"]) <= 1
		rows.append(row)
	for id in b.unit_spells(by):
		var sp := b.unit_spell(by, id)
		if sp.is_empty():
			continue
		var cmd := {"act": "ability", "kind": "spell", "id": str(id), "target": ""}
		rows.append(_row(by, "spell", cmd, str(sp.get("name", id)), b.pay_text(by, GameCombat.ability_cost(sp, u.level)), sp, _row_why(by, cmd, sp)))
	for id in b.unit_feats(by):
		var ab := b.unit_feat(by, id)
		var cmd := {"act": "ability", "kind": "feat", "id": str(id), "target": ""}
		var hp := GameFeats.hp_cost(u, str(id), int(b.unit_numbers(by)["max_hp"]))
		rows.append(_row(by, "feat", cmd, GameFeats.feat_name(str(id)), "%s HP" % GameText.num(hp) if hp > 0 else "", ab, _row_why(by, cmd, ab)))
	if by < 0:
		var seen := {}
		for id in GamePlague.vials_carried(b.heir):
			if seen.has(id):
				continue
			seen[id] = true
			var ab := GamePlague.vial_ability(id)
			var cmd := {"act": "ability", "kind": "vial", "id": str(id), "target": ""}
			rows.append(_row(by, "item", cmd, GameItems.item_name(id), "", ab, _row_why(by, cmd, ab)))
	return rows


# ---------------------------------------------------------------- texts

func _label(by: int, cmd: Dictionary) -> String:
	match str(cmd.get("act", "")):
		"attack":
			return "Attack"
		"defend":
			return "Defend"
		"potion":
			return "Potion"
		"flee":
			return "Flee"
		"ability":
			var ab: Dictionary = _ability_of(b, by, cmd).get("ab", {})
			if str(cmd.get("kind", "")) == "feat":
				return GameFeats.feat_name(str(cmd.get("id", "")))
			return str(ab.get("name", cmd.get("id", "?")))
	return "?"


func _target_text(cmd: Dictionary) -> String:
	var target := str(cmd.get("target", ""))
	var i := _foe_index(target)
	if i >= 0 and i < b.enemies.size():
		var name := str(b.enemies[i]["name"])
		var same := 0
		var nth := 0
		for j in b.enemies.size():
			if str(b.enemies[j]["name"]) == name:
				same += 1
				if j <= i:
					nth += 1
		return name if same <= 1 else "%s %d" % [name, nth]
	var who := _party_index(target)
	if who >= -1 and who < b.allies.size():
		return b.unit(who).name
	return ""


static func _clip(text: String, n: int) -> String:
	return text if text.length() <= n else text.substr(0, maxi(1, n - 1)) + "."


func describe(by: int, cmd: Dictionary) -> Dictionary:
	var ct: Dictionary = setting("chip_texts")
	if cmd.is_empty():
		var empty := str(ct["abbrev"].get("empty", "Pick"))
		return {"full": "Choose", "short": "Choose", "tiny": empty}
	var label := _label(by, cmd)
	var target := _target_text(cmd)
	var abbrev: String = str(ct["abbrev"].get(str(cmd.get("act", "")), ""))
	return {"full": label if target == "" else "%s > %s" % [label, target],
		"short": _clip(label, int(ct["short_chars"])),
		"tiny": abbrev if abbrev != "" and str(cmd.get("act", "")) != "ability" else _clip(label, int(ct["tiny_chars"]))}


func _chip(by: int, decision: String, cmd: Dictionary) -> Dictionary:
	var ab: Dictionary = setting("chip_texts")["abbrev"]
	match decision:
		"queued":
			return describe(by, cmd)
		"auto", "fallback":
			return {"full": "Auto", "short": "Auto", "tiny": str(ab.get("auto", "Auto"))}
		"held":
			return {"full": "Held", "short": "Held", "tiny": str(ab.get("held", "Held"))}
		"cover":
			return {"full": "Covers", "short": "Covers", "tiny": str(ab.get("cover", "Cover"))}
		"ko":
			return {"full": "Down", "short": "Down", "tiny": str(ab.get("ko", "Down"))}
	return describe(by, {})


func view() -> Dictionary:
	var list: Array = []
	for by in range(-1, b.allies.size()):
		var u := b.unit(by)
		var state := state_of(by)
		var entry: Dictionary = entries.get(by, {})
		var decision := "ko"
		if state == "held":
			decision = "held"
		elif state == "ready":
			match str(entry.get("src", "")):
				"manual", "repeat":
					decision = "queued"
				"cover":
					decision = "cover"
				"auto_once":
					decision = "fallback"
				_:
					decision = "auto" if bool(auto.get(by, false)) else "empty"
		var cmd: Dictionary = entry.get("cmd", {}) if decision == "queued" else {}
		var kind := decision
		if decision == "queued":
			kind = str(cmd.get("act", "empty"))
			match kind:
				"ability":
					kind = "item" if str(cmd.get("kind", "")) == "vial" else str(cmd.get("kind", "skill"))
				"potion":
					kind = "item"
		elif decision == "fallback":
			kind = "auto"
		elif decision == "cover":
			kind = "flee"
		var statuses: Array = []
		for inst in b.status_list(GameBattle.ref_of(by)):
			statuses.append(str(GameCombat.status_def(inst["id"]).get("name", inst["id"])))
		var chip := _chip(by, decision, cmd)
		var tip := "%s  HP %s/%s  MP %s/%s" % [u.name, GameText.num(u.hp), GameText.num(int(b.unit_numbers(by)["max_hp"])), GameText.num(u.mp), GameText.num(int(b.unit_numbers(by)["max_mp"]))]
		if not statuses.is_empty():
			tip += "\n" + ", ".join(statuses)
		if decision == "queued":
			tip += "\n" + str(chip["full"])
		elif decision in ["auto", "fallback"]:
			tip += "\n" + GameSkills.style_text(u)
		list.append({"by": by, "ref": GameBattle.ref_of(by), "name": u.name, "hp": u.hp, "max_hp": int(b.unit_numbers(by)["max_hp"]),
			"mp": u.mp, "max_mp": int(b.unit_numbers(by)["max_mp"]), "state": state, "auto": bool(auto.get(by, false)),
			"decision": decision, "chip": chip, "kind": kind, "statuses": statuses, "tip": tip})
	return {"number": number, "cursor": cursor, "ready": ready(), "can_back": not _order.is_empty(), "can_repeat": can_repeat(),
		"flee": flee_by != -2, "auto_commit": auto_commits(), "manual_count": manual_count(), "over": b.is_over(), "members": list}


# ---------------------------------------------------------------- playing the round

## The heir's slot: the plan through the battle's own public methods (the old buttons).
func _heir_act(plan: Dictionary) -> void:
	if str(plan.get("act", "")) == "defend":
		b.defend()
	else:
		GameTactics.act(b, plan)


func resolve() -> Dictionary:
	var log_from := b.log.size()
	if not ready():
		return {"log_from": log_from, "over": b.is_over(), "result": b.result, "played": false}
	var fleeing := flee_by != -2
	var entry: Dictionary = entries.get(-1, {})
	var src := str(entry.get("src", ""))
	var held := b.heir_skip
	var heir_manual := not fleeing and not held and src in ["manual", "repeat"]
	var coated: Array = []
	if not fleeing and not held and not heir_manual and not b.heir.inventory.is_empty() and b.coating.is_empty():
		GamePlague.auto_coat(b)   # an Auto heir may first coat the blade (no turn), as auto_turn does
		if not b.coating.is_empty():
			coated = b.events.duplicate()
	b.begin_round()
	b.events.append({"type": "round", "n": number})
	var plans := {}
	# ---- the heir's slot, always first
	if fleeing:
		b.events.append({"type": "act", "by": -1, "manual": flee_by == -1, "flee": true})
		b.flee()   # rolls once, on the heir's stats; success ends the fight for everyone
	elif held:
		b.events.append({"type": "act", "by": -1, "manual": false, "held": true})
		b.pass_turn()
	else:
		var plan := plan_for(b, -1, entry["cmd"]) if heir_manual else {}
		if not plan.is_empty():
			b.events.append({"type": "act", "by": -1, "manual": true})
			_heir_act(plan)
		else:
			b.events.append({"type": "act", "by": -1, "manual": false})
			if heir_manual:   # what was chosen is no longer possible
				b.events.append({"type": "act", "by": -1, "manual": false, "fallback": true})
				b._say("%s improvises." % b.heir.name)
			b.events.append_array(coated)
			_heir_act(GameTactics.choose(b, -1))
		if not b.round_acted and b.result == "":   # the battle turned the plan down: a plain blow, so a turn is never lost
			GameTactics.act(b, {"act": "attack", "target": b.first_target()})
	# ---- the companions and the foes
	for ai in entries:
		if ai < 0:
			continue
		var e: Dictionary = entries[ai]
		if fleeing and bool(setting("flee_covers_party")) and str(e["src"]) != "held":
			plans[ai] = {"act": "pass", "text": "%s covers the retreat." % b.allies[ai].name}
		elif not fleeing and str(e["src"]) in ["manual", "repeat"]:
			plans[ai] = e["cmd"]
	b.end_round(plans)
	# ---- bookkeeping
	if not fleeing:
		last = {}
		for by in entries:
			if str(entries[by]["src"]) in ["manual", "repeat"]:
				last[by] = (entries[by]["cmd"] as Dictionary).duplicate(true)
	var out := {"log_from": log_from, "over": b.is_over(), "result": b.result, "played": true}
	if not b.is_over():
		begin_round()
	return out
